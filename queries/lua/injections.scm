; extends

;; comment '-- $lang' after a string to highlight the string as $lang
;; Examples:
;;   local go = 'x := 2' --go
;;   go = 'x := 3' --go
;;   local t = {
;;     go = 'x := 2' --go
;;   }
(
  [
    (field
      value: (string (string_content) @injection.content))
    (variable_declaration
      (assignment_statement
        (expression_list
          value: (string
            content: (string_content) @injection.content))))
    (assignment_statement
      (expression_list
        value: (string
          content: (string_content) @injection.content)))
  ]
  .
  (comment
    content: (comment_content) @injection.language (#offset! @injection.language 0 1 0 0))
)
