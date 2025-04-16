// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RTLSDRWrapper",
    products: [
        .library(name: "RTLSDRWrapper", targets: ["RTLSDRWrapper"]),
    ],
    targets: [
        .target(
            name: "CLIBUSB",
            path: "Sources/CLIBUSB",
            exclude: ["libusb-1.0.a"],
            sources: ["placeholder.c"],
            linkerSettings: [
                .unsafeFlags(["-L./Sources/CLIBUSB", "-lusb-1.0"]),
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreFoundation", .when(platforms: [.macOS])),
                .linkedFramework("Security", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "CRTLSDR",
            dependencies: ["CLIBUSB"],
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
