cmake_minimum_required(VERSION 3.16)

project(NextGenCockpit VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 COMPONENTS Quick REQUIRED)

qt_add_executable(appNextGenCockpit
    main.cpp
)

qt_add_qml_module(appNextGenCockpit
    URI NextGenCockpit
    VERSION 1.0
    # QML is compiled at startup instead of ahead of time to C++. This avoids the
    # Qt 6.8 + MinGW Makefiles "No rule to make target .rcc/qmlcache/..." error.
    NO_CACHEGEN
    QML_FILES
        main.qml
        VehicleSim.qml
        Theme.qml
        Backdrop.qml
        LidarScene.qml
        LensFrame.qml
        SpeedCluster.qml
        LeftPanel.qml
        RightPanel.qml
        DeckTabs.qml
        CardDrive.qml
        CardSafety.qml
        CardSensors.qml
        CardNavMedia.qml
        CardVehicle.qml
        CardRoad.qml
        CardHealth.qml
        CardEnergy.qml
        Sparkline.qml
        EvidencePanel.qml
        ControlDeck.qml
        DeckButton.qml
        Telltales.qml
        TelltaleIcon.qml
        GearRail.qml
        ModeDock.qml
        AlertBanner.qml
        HelpOverlay.qml
        Indicator.qml
        TurnArrow.qml
        Caption.qml
        CoPilotDisplay.qml
        SignalSimulator.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appNextGenCockpit PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appNextGenCockpit
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appNextGenCockpit
    PRIVATE Qt6::Quick)

include(GNUInstallDirs)
install(TARGETS appNextGenCockpit
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
