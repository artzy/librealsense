// License: Apache 2.0. See LICENSE file in root directory.
// Copyright(c) 2026 RealSense, Inc. All Rights Reserved.

#include <librealsense2/rs.hpp>

#include <chrono>
#include <iomanip>
#include <iostream>
#include <thread>
#include <vector>

namespace {

struct temperature_option
{
    rs2_option id;
    const char * name;
};

const std::vector< temperature_option > temperature_options = {
    { RS2_OPTION_ASIC_TEMPERATURE, "Asic Temperature" },
    { RS2_OPTION_PROJECTOR_TEMPERATURE, "Projector Temperature" },
    { RS2_OPTION_MOTION_MODULE_TEMPERATURE, "Motion Module Temperature" },
};

void print_supported_options( rs2::sensor const & sensor )
{
    std::cout << "Supported temperature options on "
              << sensor.get_info( RS2_CAMERA_INFO_NAME ) << ":\n";

    bool any = false;
    for( auto const & opt : temperature_options )
    {
        if( sensor.supports( opt.id ) )
        {
            any = true;
            auto range = sensor.get_option_range( opt.id );
            std::cout << "  " << opt.name << " (range " << range.min << " .. " << range.max << " C)\n";
        }
    }

    if( !any )
        std::cout << "  (none)\n";
}

void print_current_temperatures( rs2::sensor const & sensor )
{
    for( auto const & opt : temperature_options )
    {
        if( !sensor.supports( opt.id ) )
            continue;

        try
        {
            float temp = sensor.get_option( opt.id );
            std::cout << "  " << opt.name << ": "
                      << std::fixed << std::setprecision( 1 ) << temp << " C\n";
        }
        catch( const rs2::error & e )
        {
            std::cerr << "  " << opt.name << ": failed - " << e.what() << '\n';
        }
    }
}

}  // namespace

// Read device temperature options (e.g. D415 Asic / Projector) while depth is streaming.
int main() try
{
    rs2::pipeline pipe;
    rs2::config cfg;
    cfg.enable_stream( RS2_STREAM_DEPTH, 640, 480, RS2_FORMAT_Z16, 30 );

    auto profile = pipe.start( cfg );
    auto dev = profile.get_device();

    std::cout << "Device: " << dev.get_info( RS2_CAMERA_INFO_NAME ) << '\n';

    for( auto && sensor : dev.query_sensors() )
        print_supported_options( sensor );

    std::cout << "\nWaiting for streaming to stabilize...\n";
    pipe.wait_for_frames();
    std::this_thread::sleep_for( std::chrono::seconds( 2 ) );

    std::cout << "Current temperature readings:\n";
    for( auto && sensor : dev.query_sensors() )
        print_current_temperatures( sensor );

    pipe.stop();
    return EXIT_SUCCESS;
}
catch( const rs2::error & e )
{
    std::cerr << "RealSense error calling " << e.get_failed_function() << "(" << e.get_failed_args()
              << "):\n    " << e.what() << std::endl;
    return EXIT_FAILURE;
}
catch( const std::exception & e )
{
    std::cerr << e.what() << std::endl;
    return EXIT_FAILURE;
}
