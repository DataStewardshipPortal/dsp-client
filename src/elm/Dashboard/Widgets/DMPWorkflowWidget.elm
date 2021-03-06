module Dashboard.Widgets.DMPWorkflowWidget exposing (view)

import ActionResult exposing (ActionResult)
import Common.AppState exposing (AppState)
import Common.Html exposing (emptyNode)
import Common.Locale exposing (l, lf, lx)
import Html exposing (Html, a, div, img, p, text)
import Html.Attributes exposing (class, href, src)
import Questionnaires.Common.Questionnaire exposing (Questionnaire)
import Questionnaires.Routes exposing (Route(..))
import Routes
import Routing


l_ : String -> AppState -> String
l_ =
    l "Dashboard.Widgets.DMPWorkflowWidget"


lf_ : String -> List String -> AppState -> String
lf_ =
    lf "Dashboard.Widgets.DMPWorkflowWidget"


lx_ : String -> AppState -> Html msg
lx_ =
    lx "Dashboard.Widgets.DMPWorkflowWidget"


view : AppState -> ActionResult (List Questionnaire) -> Html msg
view appState questionnaires =
    let
        visible =
            questionnaires
                |> ActionResult.map (List.length >> (==) 0)
                |> ActionResult.withDefault False
    in
    if visible then
        div [ class "DMPWorkflowWidget" ]
            [ div [ class "DMPWorkflowWidget__Message" ]
                [ text <| lf_ "welcome" [ appState.config.client.appTitle ] appState
                ]
            , div [ class "DMPWorkflowWidget__Workflow DMPWorkflowWidget__Workflow--Images" ]
                [ div [ class "step" ]
                    [ img [ src "/img/illustrations/undraw_choice.svg" ] []
                    ]
                , div [ class "step" ]
                    [ img [ src "/img/illustrations/undraw_setup_wizard.svg" ] []
                    ]
                , div [ class "step" ]
                    [ img [ src "/img/illustrations/undraw_upload.svg" ] []
                    ]
                ]
            , div [ class "DMPWorkflowWidget__Workflow DMPWorkflowWidget__Workflow--Texts" ]
                [ div [ class "step" ]
                    [ p [] [ lx_ "steps.chooseKM" appState ]
                    ]
                , div [ class "step" ]
                    [ p [] [ lx_ "steps.fillQuestionnaire" appState ]
                    ]
                , div [ class "step" ]
                    [ p [] [ lx_ "steps.getDMP" appState ]
                    ]
                ]
            , div [ class "DMPWorkflowWidget__Start" ]
                [ a [ class "btn btn-primary", href <| Routing.toUrl appState <| Routes.QuestionnairesRoute <| CreateRoute Nothing ]
                    [ lx_ "startPlanning" appState ]
                ]
            ]

    else
        emptyNode
