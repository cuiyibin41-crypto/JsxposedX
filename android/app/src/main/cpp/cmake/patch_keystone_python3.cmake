function(patch_keystone_python3 source_dir)
    set(componentinfo_path
        "${source_dir}/llvm/utils/llvm-build/llvmbuild/componentinfo.py")
    if(NOT EXISTS "${componentinfo_path}")
        return()
    endif()

    file(READ "${componentinfo_path}" componentinfo_content)
    if(componentinfo_content MATCHES "print >>sys\\.stderr, ")
        string(REPLACE
            "print >>sys.stderr, "
            "print("
            componentinfo_content
            "${componentinfo_content}")
        string(REPLACE
            "section, path, \"unable to instantiate: %r\" % type_name)"
            "section, path, \"unable to instantiate: %r\" % type_name), file=sys.stderr)"
            componentinfo_content
            "${componentinfo_content}")
    endif()
    if(componentinfo_content MATCHES "e\\.message")
        string(REPLACE
            "e.message"
            "str(e)"
            componentinfo_content
            "${componentinfo_content}")
    endif()
    file(WRITE "${componentinfo_path}" "${componentinfo_content}")
endfunction()
