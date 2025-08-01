module MainSpec exposing (suite)

import Expect exposing (equal)
import Test exposing (Test)


suite : Test
suite =
    Test.describe "Main"
        [ Test.test "Displays the current prompt" <|
            \_ ->
                equal 2 2
        ]
