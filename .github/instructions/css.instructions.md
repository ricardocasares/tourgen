---
applyTo: "**/*.{elm,css}"
---

# CSS Instructions

- @tailwindcss/vite dependency is already installed and configured
- daisyui dependency is already installed and configured
- src/main.css is already present and configured
- Do not install any dependencies for customizing styles

## Using CSS classes in Elm

When creating components in Elm language, always favor composability:

```elm
-- Bad: This element cannot be extended or composed
card: String -> Html msg
card title = div [ class "card bg-info" ] [ text title ]


-- Good: The card element can be extended with new classes
card: List (Attribute msg) -> List (Html msg) -> Html msg
card attr children =
    div ([ class "card bg-info" ] ++ attrs) children


-- Good: The card element can be composed with children
view model =
    card [ class "text-3xl" ] [ button [ class "button" ] [ text "Button" ] ]
```
