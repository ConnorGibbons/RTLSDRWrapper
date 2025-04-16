// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RTLSDRWrapper",
    products: [
        .library(
            name: "RTLSDRWrapper",
            targets: ["RTLSDRWrapper"]),
    ],
    targets: [
        .systemLibrary(
            name: "libusb",
            pkgConfig: "libusb-1.0"
        ),
        .target(
            name: "CRTLSDR",
            dependencies: ["libusb"],
            path: "./Sources/CRTLSDR",
            exclude: [
                "src/rtl_adsb.c",
                "src/rtl_biast.c",
                "src/rtl_eeprom.c",
                "src/rtl_fm.c",
                "src/rtl_power.c",
                "src/rtl_sdr.c",
                "src/rtl_tcp.c",
                "src/rtl_test.c",
                "src/CMakeLists.txt",
                "src/Makefile.am",
                "src/rtlsdr.rc.in",
            ],
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("src"),
                .define("HAVE_LIBUSB", to: "1")
            ],
            linkerSettings: [
            ]
        ),
        .target(
            name: "RTLSDRWrapper",
            dependencies: ["CRTLSDR"]
        ),
        .testTarget(
            name: "RTLSDRWrapperTests",
            dependencies: ["RTLSDRWrapper"]
        ),
    ]
)
        
