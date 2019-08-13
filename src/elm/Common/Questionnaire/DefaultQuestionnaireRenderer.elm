module Common.Questionnaire.DefaultQuestionnaireRenderer exposing
    ( defaultQuestionnaireRenderer
    , renderOptionAdvice
    , renderOptionBadges
    , renderOptionLabel
    , renderQuestionDescription
    , renderQuestionLabel
    )

import Common.ApiError exposing (ApiError)
import Common.Html exposing (emptyNode, fa)
import Common.Questionnaire.Msgs exposing (CustomFormMessage)
import FormEngine.View exposing (FormRenderer)
import Html exposing (..)
import Html.Attributes exposing (class, href, target)
import KMEditor.Common.KnowledgeModel.Answer exposing (Answer)
import KMEditor.Common.KnowledgeModel.Expert exposing (Expert)
import KMEditor.Common.KnowledgeModel.KnowledgeModel as KnowledgeModel exposing (KnowledgeModel)
import KMEditor.Common.KnowledgeModel.Level exposing (Level)
import KMEditor.Common.KnowledgeModel.Metric exposing (Metric)
import KMEditor.Common.KnowledgeModel.Question as Question exposing (Question)
import KMEditor.Common.KnowledgeModel.Reference exposing (Reference(..))
import KMEditor.Common.KnowledgeModel.Reference.ResourcePageReferenceData exposing (ResourcePageReferenceData)
import KMEditor.Common.KnowledgeModel.Reference.URLReferenceData exposing (URLReferenceData)
import List.Extra as List
import Markdown
import Maybe.Extra as Maybe


defaultQuestionnaireRenderer : KnowledgeModel -> List Level -> List Metric -> FormRenderer CustomFormMessage Question Answer ApiError
defaultQuestionnaireRenderer km levels metrics =
    { renderQuestionLabel = renderQuestionLabel
    , renderQuestionDescription = renderQuestionDescription levels km
    , renderOptionLabel = renderOptionLabel
    , renderOptionBadges = renderOptionBadges metrics
    , renderOptionAdvice = renderOptionAdvice
    }


renderQuestionLabel : Question -> Html msg
renderQuestionLabel question =
    text <| Question.getTitle question


renderQuestionDescription : List Level -> KnowledgeModel -> Question -> Html msg
renderQuestionDescription levels km question =
    let
        description =
            Question.getText question
                |> Maybe.map (\t -> p [ class "form-text text-muted" ] [ Markdown.toHtml [] t ])
                |> Maybe.withDefault (text "")

        extraData =
            viewExtraData levels <| createQuestionExtraData km question
    in
    div []
        [ description
        , extraData
        ]


renderOptionLabel : Answer -> Html msg
renderOptionLabel answer =
    text answer.label


renderOptionBadges : List Metric -> Answer -> Html msg
renderOptionBadges metrics answer =
    let
        getMetricName uuid =
            List.find ((==) uuid << .uuid) metrics
                |> Maybe.map .title
                |> Maybe.withDefault "Unknown"

        getBadgeClass value =
            (++) "badge-value-" <| String.fromInt <| (*) 10 <| round <| value * 10

        metricExists measure =
            List.find ((==) measure.metricUuid << .uuid) metrics /= Nothing

        createBadge metricMeasure =
            span [ class <| "badge " ++ getBadgeClass metricMeasure.measure ]
                [ text <| getMetricName metricMeasure.metricUuid ]
    in
    if List.isEmpty answer.metricMeasures then
        emptyNode

    else
        div [ class "badges" ]
            (List.filter metricExists answer.metricMeasures
                |> List.map createBadge
            )


renderOptionAdvice : Answer -> Html msg
renderOptionAdvice answer =
    case answer.advice of
        Just advice ->
            div [ class "alert alert-info" ] [ Markdown.toHtml [] advice ]

        _ ->
            emptyNode



-- Question Extra data


type alias FormExtraData =
    { resourcePageReferences : List ResourcePageReferenceData
    , urlReferences : List URLReferenceData
    , experts : List Expert
    , requiredLevel : Maybe Int
    }


createQuestionExtraData : KnowledgeModel -> Question -> FormExtraData
createQuestionExtraData km question =
    let
        foldReferences reference extraData =
            case reference of
                ResourcePageReference data ->
                    { extraData | resourcePageReferences = extraData.resourcePageReferences ++ [ data ] }

                URLReference data ->
                    { extraData | urlReferences = extraData.urlReferences ++ [ data ] }

                _ ->
                    extraData

        newExtraData =
            { resourcePageReferences = []
            , urlReferences = []
            , experts = KnowledgeModel.getQuestionExperts (Question.getUuid question) km
            , requiredLevel = Question.getRequiredLevel question
            }
    in
    KnowledgeModel.getQuestionReferences (Question.getUuid question) km
        |> List.foldl foldReferences newExtraData


viewExtraData : List Level -> FormExtraData -> Html msg
viewExtraData levels data =
    let
        isEmpty =
            List.isEmpty data.resourcePageReferences
                && List.isEmpty data.urlReferences
                && List.isEmpty data.experts
                && Maybe.isNothing data.requiredLevel
    in
    if isEmpty then
        emptyNode

    else
        p [ class "extra-data" ]
            [ viewRequiredLevel levels data.requiredLevel
            , viewResourcePageReferences data.resourcePageReferences
            , viewUrlReferences data.urlReferences
            , viewExperts data.experts
            ]


viewRequiredLevel : List Level -> Maybe Int -> Html msg
viewRequiredLevel levels questionLevel =
    case List.find (.level >> (==) (questionLevel |> Maybe.withDefault 0)) levels of
        Just level ->
            span []
                [ span [ class "caption" ]
                    [ fa "check-square-o"
                    , text "Desirable: "
                    , span [] [ text level.title ]
                    ]
                ]

        Nothing ->
            emptyNode


type alias ViewExtraItemsConfig a msg =
    { icon : String
    , label : String
    , viewItem : a -> Html msg
    }


viewExtraItems : ViewExtraItemsConfig a msg -> List a -> Html msg
viewExtraItems cfg list =
    if List.length list == 0 then
        emptyNode

    else
        let
            items =
                List.map cfg.viewItem list
                    |> List.intersperse (span [ class "separator" ] [ text ", " ])
        in
        span []
            (span [ class "caption" ] [ fa cfg.icon, text (cfg.label ++ ": ") ] :: items)


viewResourcePageReferences : List ResourcePageReferenceData -> Html msg
viewResourcePageReferences =
    viewExtraItems
        { icon = "book"
        , label = "Data Stewardship for Open Science"
        , viewItem = viewResourcePageReference
        }


viewResourcePageReference : ResourcePageReferenceData -> Html msg
viewResourcePageReference data =
    a [ href <| "/book-references/" ++ data.shortUuid, target "_blank" ]
        [ text data.shortUuid ]


viewUrlReferences : List URLReferenceData -> Html msg
viewUrlReferences =
    viewExtraItems
        { icon = "external-link"
        , label = "External Links"
        , viewItem = viewUrlReference
        }


viewUrlReference : URLReferenceData -> Html msg
viewUrlReference data =
    a [ href data.url, target "_blank" ]
        [ text data.label ]


viewExperts : List Expert -> Html msg
viewExperts =
    viewExtraItems
        { icon = "address-book-o"
        , label = "Experts"
        , viewItem = viewExpert
        }


viewExpert : Expert -> Html msg
viewExpert expert =
    span []
        [ text expert.name
        , text " ("
        , a [ href <| "mailto:" ++ expert.email ] [ text expert.email ]
        , text ")"
        ]