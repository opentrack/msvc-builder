if(NOT IS_DIRECTORY "${SDK_ROOT}")
    message(FATAL_ERROR "SDK_ROOT '${SDK_ROOT}' doesn't exist")
endif()

function(setq name value)
    set("${name}" "${SDK_ROOT}/src/deps/${value}" CACHE INTERNAL "" FORCE)
endfunction()

function(setw name value)
    set("${name}" "${SDK_ROOT}/build/${value}" CACHE INTERNAL "" FORCE)
endfunction()

set(opentrack_install-debug-info TRUE CACHE INTERNAL "" FORCE)

if(EXISTS "${SDK_ROOT}/src/deps/nonfree/.git")
    setq(SDK_KINECT20 "nonfree/Kinect-v2.0")
    setq(SDK_REALSENSE "nonfree/RSSDK-R2")
    setq(SDK_TOBII "nonfree/tobii-streamengine")
endif()
setq(SDK_VJOYSTICK "vjoystick")
setq(SDK_PS3EYEDRIVER "PS3EYEDriver")
setq(SDK_VALVE_STEAMVR "steamvr")
setq(SDK_FSUIPC "fsuipc")
setq(SDK_HYDRA "SixenseSDK")
setq(SDK_EYEWARE_BEAM "eyeware-beam-sdk")
setq(SDK_RIFT_140 "ovr_sdk_win_23.0.0/LibOVR")

set(opentrack-use-onnxruntime-avx-dispatch 1)
if(CMAKE_SIZEOF_VOID_P GREATER 4)
    setw(Qt6_DIR "qt/install/lib/cmake/Qt6")
    setw(OpenCV_DIR "opencv/install")
    setw(SDK_ARUCO_LIBPATH "aruco/src/aruco.lib")
    setw(SDK_OSCPACK "oscpack")
    setw(ONNXRuntime_DIR "onnxruntime-noavx/install")
    setw(SDK_LIBUSB "libusb")
    setq(SDK_GAMEINPUT "gameinput")
    install(FILES "${SDK_ROOT}/build/onnxruntime-noavx/install/bin/onnxruntime.dll" RENAME "onnxruntime-noavx.dll" DESTINATION "modules")
    install(FILES "${SDK_ROOT}/build/onnxruntime-avx/install/bin/onnxruntime.dll" RENAME "onnxruntime-avx.dll" DESTINATION "modules")

    set(_system_libs
        msvcp100.dll
        msvcp110.dll
        msvcp140.dll
        msvcp140_1.dll
        msvcp140_2.dll
        msvcr100.dll
        msvcr110.dll
        msvcrt.dll
        vcruntime140.dll
        vcruntime140_1.dll)
    if("$ENV{WINDIR}" STREQUAL "")
        set(_windir "c:/windows")
    else()
        set(_windir "$ENV{WINDIR}")
    endif()
    file(TO_CMAKE_PATH "${_windir}" _windir)
    foreach(lib ${_system_libs})
        install(FILES "${_windir}/system32/${lib}" DESTINATION .)
    endforeach()

else()
    message(FATAL_ERROR "TODO 32-bit")
endif()
