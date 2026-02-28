cmake_minimum_required(VERSION 3.16)

project(QtSpaceInvaders VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appQtSpaceInvaders
    main.cpp
)

qt_add_qml_module(appQtSpaceInvaders
    URI QtSpaceInvaders
    VERSION 1.0
    QML_FILES
        Main.qml
    RESOURCES
        assets/sfx/shoot.wav
        assets/sfx/alien_hit.wav
        assets/sfx/player_hit.wav
        assets/sfx/wave_clear.wav
        assets/sfx/game_over.wav
        assets/music/galactic_onslaught.mp3
        assets/music/orbital_siege_loop.mp3
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appQtSpaceInvaders PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appQtSpaceInvaders
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appQtSpaceInvaders
    PRIVATE Qt6::Quick Qt6::Multimedia
)

include(GNUInstallDirs)
install(TARGETS appQtSpaceInvaders
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
