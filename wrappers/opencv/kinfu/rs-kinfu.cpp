
#include <opencv2/imgproc.hpp>
#include <opencv2/core/ocl.hpp>
#include <opencv2/rgbd/kinfu.hpp>

#include <librealsense2/rs.hpp> // Include RealSense Cross Platform API
#include <example.hpp>         // Include short list of convenience functions for rendering

#include <thread>
#include <queue>
#include <atomic>
#include <fstream>
#include <algorithm>
#include <cstring>

using namespace cv;
using namespace cv::kinfu;

static float max_dist = 2.5;
static float min_dist = 0;


// Assigns an RGB value for each point in the pointcloud, based on the depth value
void colorize_pointcloud(const Mat points, Mat& color)
{
    // Define a vector of 3 Mat arrays which will hold the channles of points
    std::vector<Mat> channels(points.channels());
    split(points, channels);
    // Get the depth channel which we'll use to colorize the pointcloud
    color = channels[2];

    // Convert the depth matrix to unsigned char values
    float min = min_dist;
    float max = max_dist;
    color.convertTo(color, CV_8UC1, 255 / (max - min), -255 * min / (max - min));
    // Get an rgb value for each point
    applyColorMap(color, color, COLORMAP_JET);
}

#ifndef GL_BGRA
#define GL_BGRA 0x80E1
#endif

// getCloud() uses fillPtsNrm OpenCL kernel which fails on many NVIDIA drivers.
// render() uses the last raycast result and works with OpenCL enabled.
void draw_kinfu_render(const Mat& rendered, int window_w, int window_h)
{
    glClearColor(153.f / 255, 153.f / 255, 153.f / 255, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    if (rendered.empty())
        return;

    const float scale = std::min(float(window_w) / rendered.cols, float(window_h) / rendered.rows);
    const int draw_w = int(rendered.cols * scale);
    const int draw_h = int(rendered.rows * scale);
    const int draw_x = (window_w - draw_w) / 2;
    const int draw_y = (window_h - draw_h) / 2;

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, window_w, window_h, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    GLuint tex = 0;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, rendered.cols, rendered.rows, 0, GL_BGRA, GL_UNSIGNED_BYTE, rendered.data);

    glEnable(GL_TEXTURE_2D);
    glColor3f(1.f, 1.f, 1.f);
    glBegin(GL_QUADS);
    glTexCoord2f(0, 0); glVertex2i(draw_x, draw_y);
    glTexCoord2f(1, 0); glVertex2i(draw_x + draw_w, draw_y);
    glTexCoord2f(1, 1); glVertex2i(draw_x + draw_w, draw_y + draw_h);
    glTexCoord2f(0, 1); glVertex2i(draw_x, draw_y + draw_h);
    glEnd();
    glDisable(GL_TEXTURE_2D);
    glDeleteTextures(1, &tex);
}



void export_to_ply(Mat points, Mat normals)
{
    if (points.empty())
        return;
    // First generate a filename
    const size_t buffer_size = 50;
    char fname[buffer_size];
    time_t t = time(0);   // get time now
    struct tm * now = localtime(&t);
    strftime(fname, buffer_size, "%m%d%y %H%M%S.ply", now);
    std::cout << "exporting to" << fname << std::endl;

    // Get rgb values for points
    Mat color;
    colorize_pointcloud(points, color);

    // Write the ply file
    std::ofstream out(fname);
    out << "ply\n";
    out << "format binary_little_endian 1.0\n";
    out << "comment pointcloud saved from Realsense Viewer\n";
    out << "element vertex " << points.rows << "\n";
    out << "property float" << sizeof(float) * 8 << " x\n";
    out << "property float" << sizeof(float) * 8 << " y\n";
    out << "property float" << sizeof(float) * 8 << " z\n";

    out << "property float" << sizeof(float) * 8 << " nx\n";
    out << "property float" << sizeof(float) * 8 << " ny\n";
    out << "property float" << sizeof(float) * 8 << " nz\n";

    out << "property uchar red\n";
    out << "property uchar green\n";
    out << "property uchar blue\n";
    out << "end_header\n";
    out.close();

    out.open(fname, std::ios_base::app | std::ios_base::binary);
    for (int i = 0; i < points.rows; i++)
    {
        // write vertices
        out.write(reinterpret_cast<const char*>(&(points.at<float>(i, 0))), sizeof(float));
        out.write(reinterpret_cast<const char*>(&(points.at<float>(i, 1))), sizeof(float));
        out.write(reinterpret_cast<const char*>(&(points.at<float>(i, 2))), sizeof(float));

        // write normals
        out.write(reinterpret_cast<const char*>(&(normals.at<float>(i, 0))), sizeof(float));
        out.write(reinterpret_cast<const char*>(&(normals.at<float>(i, 1))), sizeof(float));
        out.write(reinterpret_cast<const char*>(&(normals.at<float>(i, 2))), sizeof(float));

        // write colors
        out.write(reinterpret_cast<const char*>(&(color.at<uchar>(i, 0))), sizeof(uint8_t));
        out.write(reinterpret_cast<const char*>(&(color.at<uchar>(i, 1))), sizeof(uint8_t));
        out.write(reinterpret_cast<const char*>(&(color.at<uchar>(i, 2))), sizeof(uint8_t));
    }
}


// Thread-safe queue for OpenCV's Mat objects
class mat_queue
{
public:
    void push(Mat& item)
    {
        std::lock_guard<std::mutex> lock(_mtx);
        queue.push(item);
    }
    int try_get_next_item(Mat& item)
    {
        std::lock_guard<std::mutex> lock(_mtx);
        if (queue.empty())
            return false;
        item = std::move(queue.front());
        queue.pop();
        return true;
    }
private:
    std::queue<Mat> queue;
    std::mutex _mtx;
};


int main(int argc, char **argv)
{
    // Declare KinFu and params pointers
    Ptr<KinFu> kf;
    Ptr<Params> params = Params::defaultParams();

    // Create a pipeline and configure it
    rs2::pipeline p;
    rs2::config cfg;
    float depth_scale;
    // 640x480 is closer to KinFu defaults and more stable than 1280x720 for ICP
    cfg.enable_stream(RS2_STREAM_DEPTH, 640, 480, RS2_FORMAT_Z16);
    auto profile = p.start(cfg);
    auto dev = profile.get_device();
    auto stream_depth = profile.get_stream(RS2_STREAM_DEPTH);

    // Get a new frame from the camera
    rs2::frameset data = p.wait_for_frames();
    auto d = data.get_depth_frame();
    
    for (rs2::sensor& sensor : dev.query_sensors())
    {
        if (rs2::depth_sensor dpt = sensor.as<rs2::depth_sensor>())
        {
            // DEFAULT preset: less noise than HIGH_DENSITY, better ICP stability
            dpt.set_option(RS2_OPTION_VISUAL_PRESET, RS2_RS400_VISUAL_PRESET_DEFAULT);
            // Depth scale is needed for the kinfu set-up
            depth_scale = dpt.get_depth_scale();
            break;
        }
    }

    // Declare post-processing filters for better results
    auto decimation = rs2::decimation_filter();
    decimation.set_option(RS2_OPTION_FILTER_MAGNITUDE, 2);
    auto spatial = rs2::spatial_filter();
    auto temporal = rs2::temporal_filter();

    auto clipping_dist = max_dist / depth_scale; // convert clipping_dist to raw depth units

    auto depth_profile = stream_depth.as<rs2::video_stream_profile>();
    auto intrin = depth_profile.get_intrinsics();
    const int raw_w = depth_profile.width();
    const int raw_h = depth_profile.height();

    // Use decimation once to get the final size of the frame
    d = decimation.process(d);
    auto w = d.get_width();
    auto h = d.get_height();
    Size size = Size(w, h);

    // Scale intrinsics to match decimated depth resolution
    const float sx = float(w) / raw_w;
    const float sy = float(h) / raw_h;

    // Configure kinfu's parameters
    params->frameSize = size;
    params->intr = Matx33f(intrin.fx * sx, 0, intrin.ppx * sx,
                           0, intrin.fy * sy, intrin.ppy * sy,
                           0, 0, 1);
    params->depthFactor = 1 / depth_scale;

    // Relax ICP thresholds for RealSense depth noise / hand-held motion
    params->icpDistThresh = 0.2f;
    params->icpAngleThresh = float(60. * CV_PI / 180.);

    // OpenCL TSDF works on RTX, but OpenCL ICP (getAb) often fails on NVIDIA and
    // causes endless reset. CPU KinFu uses Mat-based ICP which is stable.
    cv::ocl::setUseOpenCL(false);
    std::cout << "KinFu: CPU path (stable ICP; OpenCL ICP fails on many NVIDIA GPUs)" << std::endl;

    // Initialize KinFu object
    try {
        kf = KinFu::create(params);
    } catch (const cv::Exception& e) {
        std::cerr << "KinFu init failed: " << e.what() << std::endl;
        return 1;
    }

    bool after_reset = false;
    mat_queue render_queue;

    window app(1280, 720, "RealSense KinectFusion Example");
    glfw_state app_state;
    register_glfw_callbacks(app, app_state);

    std::atomic_bool stopped(false);

    // This thread runs KinFu algorithm and calculates the pointcloud by fusing depth data from subsequent depth frames
    std::thread calc_cloud_thread([&]() {
        Mat _rendered;
        int icp_fail_streak = 0;
        const int reset_after_fails = 30;
        try {
            while (!stopped)
            {
                rs2::frameset data = p.wait_for_frames(); // Wait for next set of frames from the camera

                auto d = data.get_depth_frame();
                // Use post processing to improve results
                d = decimation.process(d);
                d = spatial.process(d);
                d = temporal.process(d);

                // Copy depth to owned buffer, then clip (avoid mutating RealSense filter buffers)
                Mat f(h, w, CV_16UC1);
                memcpy(f.data, d.get_data(), size_t(w) * h * sizeof(uint16_t));
                uint16_t* p_depth_frame = reinterpret_cast<uint16_t*>(f.data);
#pragma omp parallel for schedule(dynamic)
                for (int y = 0; y < h; y++)
                {
                    auto depth_pixel_index = y * w;
                    for (int x = 0; x < w; x++, ++depth_pixel_index)
                    {
                        if (p_depth_frame[depth_pixel_index] > clipping_dist)
                            p_depth_frame[depth_pixel_index] = 0;
                    }
                }

                // Run KinFu (CPU Mat path when OpenCL is disabled at create time)
                if (!kf->update(f))
                {
                    icp_fail_streak++;
                    if (icp_fail_streak >= reset_after_fails)
                    {
                        kf->reset();
                        icp_fail_streak = 0;
                        after_reset = true;
                        std::cout << "reset (ICP lost for " << reset_after_fails << " frames)" << std::endl;
                    }
                }
                else
                {
                    icp_fail_streak = 0;
                    if (!after_reset)
                    {
                        try
                        {
                            UMat rendered;
                            kf->render(rendered);
                            rendered.copyTo(_rendered);
                            render_queue.push(_rendered);
                        }
                        catch (const std::exception& e)
                        {
                            std::cerr << "render failed: " << e.what() << std::endl;
                        }
                    }
                }
                after_reset = false;
            }
        }
        catch (const std::exception& e)
        {
            std::cerr << "KinFu worker error: " << e.what() << std::endl;
        }
    });

    // Main thread handles rendering
    Mat rendered;
    while (app)
    {
        render_queue.try_get_next_item(rendered);
        draw_kinfu_render(rendered, 1280, 720);
    }
    stopped = true;
    calc_cloud_thread.join();

    return 0;
}
