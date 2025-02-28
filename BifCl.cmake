
# A macro to define a command that uses the BIF compiler to produce C++
# segments and Zeek language declarations from a .bif file. The outputs
# are returned in BIF_OUTPUT_{CC,H,BRO}. By default, it runs bifcl in
# alternative mode (-a; suitable for standalone compilation). If
# an additional parameter "standard" is given, it runs it in standard mode
# for inclusion in NetVar.*. If an additional parameter "plugin" is given,
# it runs it in plugin mode (-p). In the latter case, one more argument
# is required with the plugin's name.
#
# The macro also creates a target that can be used to define depencencies on
# the generated files. The name of the target depends on the mode and includes
# a normalized path to the input bif to make it unique. The target is added
# automatically to bro_ALL_GENERATED_OUTPUTS.
macro(bif_target bifInput)
    set(target "")
    get_filename_component(bifInputBasename "${bifInput}" NAME)

    if ( "${ARGV1}" STREQUAL "standard" )
        set(bifcl_args "")
	set(target "bif-std-${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}")
        set(bifOutputs
            ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}.func_def
            ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}.func_h
            ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}.func_init
            ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}.netvar_def
            ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}.netvar_h
            ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}.netvar_init)
        set(BIF_OUTPUT_CC  ${bifInputBasename}.func_def
                           ${bifInputBasename}.func_init
                           ${bifInputBasename}.netvar_def
                           ${bifInputBasename}.netvar_init)
        set(BIF_OUTPUT_H   ${bifInputBasename}.func_h
                           ${bifInputBasename}.netvar_h)
        set(BIF_OUTPUT_BRO ${Zeek_BINARY_DIR}/scripts/base/bif/${bifInputBasename}.zeek)
        set(bro_BASE_BIF_SCRIPTS ${bro_BASE_BIF_SCRIPTS} ${BIF_OUTPUT_BRO} CACHE INTERNAL "Zeek script stubs for BIFs in base distribution of Zeek" FORCE) # Propogate to top-level

        # Do this here so that all of the necessary files for each individual BIF get added to clang-tidy
        add_clang_tidy_files(${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}.func_def)

    elseif ( "${ARGV1}" STREQUAL "plugin" )
        set(plugin_name ${ARGV2})
        set(plugin_name_canon ${ARGV3})
        set(plugin_is_static ${ARGV4})
        set(target "bif-plugin-${plugin_name_canon}-${bifInputBasename}")
        set(bifcl_args "-p;${plugin_name}")
        set(bifOutputs
            ${bifInputBasename}.h
            ${bifInputBasename}.cc
            ${bifInputBasename}.init.cc
            ${bifInputBasename}.register.cc)

        if ( plugin_is_static )
            set(BIF_OUTPUT_CC  ${bifInputBasename}.cc
                               ${bifInputBasename}.init.cc)
            set(bro_REGISTER_BIFS ${bro_REGISTER_BIFS} ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename} CACHE INTERNAL "BIFs for automatic registering" FORCE) # Propagate to top-level.
        else ()
            set(BIF_OUTPUT_CC  ${bifInputBasename}.cc
                               ${bifInputBasename}.init.cc
                               ${bifInputBasename}.register.cc)
        endif()

        # Do this here so that all of the necessary files for each individual BIF get added to clang-tidy
        foreach (bif_cc_file ${BIF_OUTPUT_CC})
            add_clang_tidy_files(${CMAKE_CURRENT_BINARY_DIR}/${bif_cc_file})
        endforeach(bif_cc_file)

        set(BIF_OUTPUT_H   ${bifInputBasename}.h)

        if ( NOT ZEEK_PLUGIN_BUILD_DYNAMIC )
            set(BIF_OUTPUT_BRO ${Zeek_BINARY_DIR}/scripts/base/bif/plugins/${plugin_name_canon}.${bifInputBasename}.zeek)
        else ()
            set(BIF_OUTPUT_BRO ${BRO_PLUGIN_BIF}/${bifInputBasename}.zeek)
        endif()

        set(bro_PLUGIN_BIF_SCRIPTS ${bro_PLUGIN_BIF_SCRIPTS} ${BIF_OUTPUT_BRO} CACHE INTERNAL "Zeek script stubs for BIFs in Zeek plugins" FORCE) # Propogate to top-level

    else ()
        # Alternative mode. These will get compiled in automatically.
        set(bifcl_args "-s")
        set(target "bif-alt-${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename}")
        set(bifOutputs
            ${bifInputBasename}.h
            ${bifInputBasename}.cc
            ${bifInputBasename}.init.cc)
        set(BIF_OUTPUT_CC  ${bifInputBasename}.cc)
        set(BIF_OUTPUT_H   ${bifInputBasename}.h)

        # Do this here so that all of the necessary files for each individual BIF get added to clang-tidy
        foreach (bif_cc_file ${BIF_OUTPUT_CC})
            add_clang_tidy_files(${CMAKE_CURRENT_BINARY_DIR}/${bif_cc_file})
        endforeach(bif_cc_file)

        # In order be able to run Zeek from the build directory, the
        # generated Zeek script needs to be inside a directory tree
        # named the same way it will be referenced from an @load.
	set(BIF_OUTPUT_BRO ${Zeek_BINARY_DIR}/scripts/base/bif/${bifInputBasename}.zeek)

        set(bro_AUTO_BIFS  ${bro_AUTO_BIFS} ${CMAKE_CURRENT_BINARY_DIR}/${bifInputBasename} CACHE INTERNAL "BIFs for automatic inclusion" FORCE) # Propagate to top-level.
        set(bro_BASE_BIF_SCRIPTS ${bro_BASE_BIF_SCRIPTS} ${BIF_OUTPUT_BRO} CACHE INTERNAL "Zeek script stubs for BIFs in base distribution of Zeek" FORCE) # Propogate to top-level

    endif ()

    if ( ZEEK_PLUGIN_INTERNAL_BUILD )
        if ( BIFCL_EXE_PATH )
            set(BifCl_EXE ${BIFCL_EXE_PATH})
        else ()
            set(BifCl_EXE "bifcl")
        endif ()
    else ()
        if ( NOT BifCl_EXE )
            if ( BRO_PLUGIN_BRO_BUILD )
                # Zeek 3.2+ has auxil/ instead of aux/
                if ( EXISTS "${BRO_PLUGIN_BRO_BUILD}/auxil" )
                    set(BifCl_EXE "${BRO_PLUGIN_BRO_BUILD}/auxil/bifcl/bifcl")
                else ()
                    set(BifCl_EXE "${BRO_PLUGIN_BRO_BUILD}/aux/bifcl/bifcl")
                endif ()
            else ()
                find_program(BifCl_EXE bifcl)

                if ( NOT BifCl_EXE )
                    message(FATAL_ERROR "Failed to find 'bifcl' program")
                endif ()
            endif ()
        endif ()
    endif ()

    set(bifclDep ${BifCl_EXE})

    add_custom_command(OUTPUT ${bifOutputs} ${BIF_OUTPUT_BRO}
                       COMMAND ${BifCl_EXE}
                       ARGS ${bifcl_args} ${CMAKE_CURRENT_SOURCE_DIR}/${bifInput} || (rm -f ${bifOutputs} && exit 1)
                       COMMAND "${CMAKE_COMMAND}"
                       ARGS -E copy ${bifInputBasename}.zeek ${BIF_OUTPUT_BRO}
                       COMMAND "${CMAKE_COMMAND}"
                       ARGS -E remove -f ${bifInputBasename}.zeek
                       DEPENDS ${bifInput}
                       DEPENDS ${bifclDep}
                       COMMENT "[BIFCL] Processing ${bifInput}"
    )

    # Make sure to escape a bunch of special characters in the path before trying to use it as a
    # regular expression below.
    string(REGEX REPLACE "([][+.*()^])" "\\\\\\1" escaped_path "${Zeek_BINARY_DIR}/src/")

    string(REGEX REPLACE "${escaped_path}" "" target "${target}")
    string(REGEX REPLACE "/" "-" target "${target}")
    add_custom_target(${target} DEPENDS ${BIF_OUTPUT_H} ${BIF_OUTPUT_CC})
    set_source_files_properties(${bifOutputs} PROPERTIES GENERATED 1)
    set(BIF_BUILD_TARGET ${target})

    set(bro_ALL_GENERATED_OUTPUTS ${bro_ALL_GENERATED_OUTPUTS} ${target} CACHE INTERNAL "automatically generated files" FORCE) # Propagate to top-level.
endmacro(bif_target)

# A macro to create a __load__.zeek file for all *.bif.zeek files in
# a given collection (which should all be in the same directory).
# It creates a corresponding target to trigger the generation.
function(bro_bif_create_loader target bifinputs)
    set(_bif_loader_dir "")

    foreach ( _bro_file ${bifinputs} )
        get_filename_component(_bif_loader_dir_tmp ${_bro_file} PATH)
        get_filename_component(_bro_file_name ${_bro_file} NAME)

        if ( _bif_loader_dir )
            if ( NOT _bif_loader_dir_tmp STREQUAL _bif_loader_dir )
                message(FATAL_ERROR "Directory of Zeek script BIF stub ${_bro_file} differs from expected: ${_bif_loader_dir}")
            endif ()
        else ()
            set(_bif_loader_dir ${_bif_loader_dir_tmp})
        endif ()

        set(_bif_loader_content "${_bif_loader_content} ${_bro_file_name}")
    endforeach ()

    if ( NOT _bif_loader_dir )
        return ()
    endif ()

    file(MAKE_DIRECTORY ${_bif_loader_dir})

    set(_bif_loader_file ${_bif_loader_dir}/__load__.zeek)
    add_custom_target(${target}
        COMMAND "sh" "-c" "rm -f ${_bif_loader_file}"
        COMMAND "sh" "-c" "for i in ${_bif_loader_content}; do echo @load ./$i >> ${_bif_loader_file}; done"
        WORKING_DIRECTORY ${_bif_loader_dir}
        VERBATIM
    )

     add_dependencies(${target} generate_outputs)
endfunction()

# A macro to create joint include files for compiling in all the
# autogenerated bif code.  Adds an empty target named ${target} (for
# compatibility) and creates ${dstdir}/__all__.bif.cc and
# ${dstdir}/__all__.bif.init.cc.
function(bro_bif_create_includes target dstdir bifinputs)
    add_custom_target(${target})
    bif_create_include(${dstdir} "" "${bifinputs}")
    bif_create_include(${dstdir} .init "${bifinputs}")
endfunction()

# Adds and empty target (for compatibility) and creates
# ${dstdir}/__all__.bif.register.cc.
function(bro_bif_create_register target dstdir bifinputs)
    add_custom_target(${target})
    bif_create_include(${dstdir} .register "${bifinputs}")
endfunction()

# Creates ${dstdir}/__all__.bif${suffix}.cc.
function(bif_create_include dstdir suffix bifinputs)
    set(dst ${dstdir}/__all__.bif${suffix}.cc)
    file(REMOVE ${dst}.tmp)
    foreach (b ${bifinputs})
        file(APPEND ${dst}.tmp "#include \"${b}${suffix}.cc\"\n")
    endforeach ()
    configure_file(${dst}.tmp ${dst} COPYONLY)
    file(REMOVE ${dst}.tmp)
endfunction()
