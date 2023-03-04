; extends

;; comment '--$lang' after a string to highlight the string as $lang
;; Examples:
;;   local go = 'x := 2' --go
;;   go = 'x := 3' --go
;;   local t = {
;;     go = 'x := 2' --go
;;   }
(
  [
    (field
      value: (string ("string_content") @content))
    (variable_declaration
      (assignment_statement
        (expression_list
          value: (string
            content: ("string_content") @content))))
    (assignment_statement
      (expression_list
        value: (string
          content: ("string_content") @content)))
  ]
  .
  (comment
    content: ("comment_content") @language (#offset! @language 0 1 0 0))
)
