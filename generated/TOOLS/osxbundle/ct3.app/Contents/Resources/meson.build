input = join_paths(source_root, 'TOOLS', 'osxbundle',
                   'ct3.app', 'Contents', 'Resources', 'icon.icns')
osxbundle = custom_target('osxbundle',
    input: input,
    output: 'icon.icns.inc',
    command: [file2string, '@INPUT@', '@OUTPUT@'],
)
sources += osxbundle
