// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RTLSDRWrapper",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RTLSDRWrapper",
            targets: ["RTLSDRWrapper"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CRTLSDR",
            dependencies: [],
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
                "src/rtlsdr.rc.in"
            ],
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("src"),
                .headerSearchPath("../../CLIBUSB/include/libusb-1.0")
            ],
            linkerSettings: [
                .unsafeFlags(["Sources/CLIBUSB/libusb-1.0.a"])
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
