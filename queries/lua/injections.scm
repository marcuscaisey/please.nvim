;; extends

(field
  name: (identifier) @_field_name
  (#eq? @_field_name "tree")
  value: (table_constructor
    (field
      name: (string
        content: ("string_content") @_filename)
        (#lua-match? @_filename "^.+%.go$")
      value: (string
        content: ("string_content") @go))))

(field
  name: (identifier) @_field_name
  (#eq? @_field_name "tree")
  value: (table_constructor
    (field
      name: (string
        content: ("string_content") @_filename)
        (#lua-match? @_filename "^.+%.py")
      value: (string
        content: ("string_content") @python))))
