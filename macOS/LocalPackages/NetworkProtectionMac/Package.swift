// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import PackageDescription

let package = Package(
    name: "NetworkProtectionMac",
    defaultLocalization: "en",
    platforms: [
        .macOS("11.4")
    ],
    products: [
        .library(name: "NetworkProtectionIPC", targets: ["NetworkProtectionIPC"]),
        .library(name: "NetworkProtectionProxy", targets: ["NetworkProtectionProxy"]),
        .library(name: "NetworkProtectionUI", targets: ["NetworkProtectionUI"]),
        .library(name: "VPNAppLauncher", targets: ["VPNAppLauncher"]),
        .library(name: "VPNAppState", targets: ["VPNAppState"]),
        .library(name: "VPNExtensionManagement", targets: ["VPNExtensionManagement"]),
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm", exact: "4.5.1"),
        .package(path: "../../SharedPackages/BrowserServicesKit"),
        .package(path: "../AppInfoRetriever"),
        .package(path: "../AppLauncher"),
        .package(path: "../UDSHelper"),
        .package(path: "../XPCHelper"),
        .package(path: "../SwiftUIExtensions"),
        .package(path: "../LoginItems"),
    ],
    targets: [

        .target(
            name: "VPNAppState",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),

        .target(
            name: "VPNExtensionManagement",
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]),

        // MARK: - NetworkProtectionIPC

        .target(
            name: "NetworkProtectionIPC",
            dependencies: [
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "XPCHelper", package: "XPCHelper"),
                .product(name: "UDSHelper", package: "UDSHelper"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        // MARK: - NetworkProtectionProxy

        .target(
            name: "NetworkProtectionProxy",
            dependencies: [
                "AppInfoRetriever",
                "VPNAppState",
                "VPNExtensionManagement",
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        // MARK: - VPNAppLauncher

        .target(
            name: "VPNAppLauncher",
            dependencies: [
                "NetworkProtectionUI",
                .product(name: "AppLauncher", package: "AppLauncher"),
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        // MARK: - VPNPixels

        .target(
            name: "VPNPixels",
            dependencies: [
                .product(name: "PixelKit", package: "BrowserServicesKit"),
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        // MARK: - NetworkProtectionUI

        .target(
            name: "NetworkProtectionUI",
            dependencies: [
                "NetworkProtectionProxy",
                "VPNAppState",
                "VPNPixels",
                .product(name: "NetworkProtection", package: "BrowserServicesKit"),
                .product(name: "PixelKit", package: "BrowserServicesKit"),
                .product(name: "SwiftUIExtensions", package: "SwiftUIExtensions"),
                .product(name: "LoginItems", package: "LoginItems"),
                .product(name: "Lottie", package: "lottie-spm")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        ),

        .testTarget(
            name: "NetworkProtectionUITests",
            dependencies: [
                "NetworkProtectionUI",
                .product(name: "NetworkProtectionTestUtils", package: "BrowserServicesKit"),
                .product(name: "LoginItems", package: "LoginItems"),
                .product(name: "PixelKitTestingUtilities", package: "BrowserServicesKit"),
            ]
        ),
    ]
)
