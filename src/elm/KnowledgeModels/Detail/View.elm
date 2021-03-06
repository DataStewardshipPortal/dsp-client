module KnowledgeModels.Detail.View exposing (view)

import Auth.Permission as Perm exposing (hasPerm)
import Common.Api.Packages as PackagesApi
import Common.AppState exposing (AppState)
import Common.Config exposing (Registry(..))
import Common.Html exposing (emptyNode, fa, faSet, linkTo)
import Common.Locale exposing (l, lg, lh, lx)
import Common.View.ItemIcon as ItemIcon
import Common.View.Modal as Modal
import Common.View.Page as Page
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import KMEditor.Routes exposing (Route(..))
import KnowledgeModels.Common.OrganizationInfo exposing (OrganizationInfo)
import KnowledgeModels.Common.PackageDetail exposing (PackageDetail)
import KnowledgeModels.Common.PackageState as PackageState
import KnowledgeModels.Common.Version as Version
import KnowledgeModels.Detail.Models exposing (..)
import KnowledgeModels.Detail.Msgs exposing (..)
import KnowledgeModels.Routes exposing (Route(..))
import Markdown
import Questionnaires.Routes
import Routes
import Utils exposing (listFilterJust, listInsertIf)


l_ : String -> AppState -> String
l_ =
    l "KnowledgeModels.Detail.View"


lh_ : String -> List (Html msg) -> AppState -> List (Html msg)
lh_ =
    lh "KnowledgeModels.Detail.View"


lx_ : String -> AppState -> Html msg
lx_ =
    lx "KnowledgeModels.Detail.View"


view : AppState -> Model -> Html Msg
view appState model =
    Page.actionResultView appState (viewPackage appState model) model.package


viewPackage : AppState -> Model -> PackageDetail -> Html Msg
viewPackage appState model package =
    div [ class "KnowledgeModels__Detail" ]
        [ header appState package
        , readme appState package
        , sidePanel appState package
        , deleteVersionModal appState model package
        ]


header : AppState -> PackageDetail -> Html Msg
header appState package =
    let
        exportAction =
            a [ class "link-with-icon", href <| PackagesApi.exportPackageUrl package.id appState, target "_blank" ]
                [ faSet "kmDetail.export" appState
                , lx_ "header.export" appState
                ]

        forkAction =
            linkTo appState
                (Routes.KMEditorRoute <| CreateRoute <| Just package.id)
                [ class "link-with-icon" ]
                [ faSet "kmDetail.createKMEditor" appState
                , lx_ "header.createKMEditor" appState
                ]

        questionnaireAction =
            linkTo appState
                (Routes.QuestionnairesRoute <| Questionnaires.Routes.CreateRoute <| Just package.id)
                [ class "link-with-icon" ]
                [ faSet "kmDetail.createQuestionnaire" appState
                , lx_ "header.createQuestionnaire" appState
                ]

        deleteAction =
            a [ onClick <| ShowDeleteDialog True, class "text-danger link-with-icon" ]
                [ fa "trash-o"
                , lx_ "header.delete" appState
                ]

        actions =
            []
                |> listInsertIf exportAction (hasPerm appState.jwt Perm.packageManagementWrite)
                |> listInsertIf forkAction (hasPerm appState.jwt Perm.knowledgeModel)
                |> listInsertIf questionnaireAction (hasPerm appState.jwt Perm.questionnaire)
                |> listInsertIf deleteAction (hasPerm appState.jwt Perm.packageManagementWrite)
    in
    div [ class "top-header" ]
        [ div [ class "top-header-content" ]
            [ div [ class "top-header-title" ] [ text package.name ]
            , div [ class "top-header-actions" ] actions
            ]
        ]


readme : AppState -> PackageDetail -> Html msg
readme appState package =
    let
        containsNewerVersions =
            (List.length <| List.filter (Version.greaterThan package.version) package.versions) > 0

        warning =
            if containsNewerVersions then
                div [ class "alert alert-warning" ]
                    [ lx_ "readme.versionWarning" appState ]

            else
                newVersionInRegistryWarning appState package
    in
    div [ class "KnowledgeModels__Detail__Readme" ]
        [ warning
        , Markdown.toHtml [ class "readme" ] package.readme
        ]


newVersionInRegistryWarning : AppState -> PackageDetail -> Html msg
newVersionInRegistryWarning appState package =
    case ( package.remoteLatestVersion, PackageState.isOutdated package.state, appState.config.registry ) of
        ( Just remoteLatestVersion, True, RegistryEnabled _ ) ->
            let
                latestPackageId =
                    package.organizationId ++ ":" ++ package.kmId ++ ":" ++ Version.toString remoteLatestVersion
            in
            div [ class "alert alert-warning" ]
                ([ fa "exclamation-triangle" ]
                    ++ lh_ "registryVersion.warning"
                        [ text (Version.toString remoteLatestVersion)
                        , linkTo appState
                            (Routes.KnowledgeModelsRoute <| ImportRoute <| Just <| latestPackageId)
                            []
                            [ lx_ "registryVersion.warning.import" appState ]
                        ]
                        appState
                )

        _ ->
            emptyNode


sidePanel : AppState -> PackageDetail -> Html msg
sidePanel appState package =
    let
        sections =
            [ sidePanelKmInfo appState package
            , sidePanelOtherVersions appState package
            , sidePanelOrganizationInfo appState package
            , sidePanelRegistryLink appState package
            ]
    in
    div [ class "KnowledgeModels__Detail__SidePanel" ]
        [ list 12 12 <| listFilterJust sections ]


sidePanelKmInfo : AppState -> PackageDetail -> Maybe ( String, Html msg )
sidePanelKmInfo appState package =
    let
        kmInfoList =
            [ ( lg "package.id" appState, text package.id )
            , ( lg "package.version" appState, text <| Version.toString package.version )
            , ( lg "package.metamodel" appState, text <| String.fromInt package.metamodelVersion )
            , ( lg "package.license" appState, text package.license )
            ]

        parentInfo =
            case package.forkOfPackageId of
                Just parentPackageId ->
                    [ ( lg "package.forkOf" appState
                      , linkTo appState
                            (Routes.KnowledgeModelsRoute <| DetailRoute parentPackageId)
                            []
                            [ text parentPackageId ]
                      )
                    ]

                Nothing ->
                    []
    in
    Just ( lg "package" appState, list 4 8 <| kmInfoList ++ parentInfo )


sidePanelOtherVersions : AppState -> PackageDetail -> Maybe ( String, Html msg )
sidePanelOtherVersions appState package =
    let
        versionLink version =
            li []
                [ linkTo appState
                    (Routes.KnowledgeModelsRoute <| DetailRoute <| package.organizationId ++ ":" ++ package.kmId ++ ":" ++ Version.toString version)
                    []
                    [ text <| Version.toString version ]
                ]

        versionLinks =
            package.versions
                |> List.filter ((/=) package.version)
                |> List.sortWith Version.compare
                |> List.reverse
                |> List.map versionLink
    in
    if List.length versionLinks > 0 then
        Just ( lg "package.otherVersions" appState, ul [] versionLinks )

    else
        Nothing


sidePanelOrganizationInfo : AppState -> PackageDetail -> Maybe ( String, Html msg )
sidePanelOrganizationInfo appState package =
    case package.organization of
        Just organization ->
            Just ( lg "package.publishedBy" appState, viewOrganization organization )

        Nothing ->
            Nothing


sidePanelRegistryLink : AppState -> PackageDetail -> Maybe ( String, Html msg )
sidePanelRegistryLink appState package =
    case package.registryLink of
        Just registryLink ->
            Just
                ( lg "package.registryLink" appState
                , a [ href registryLink, class "link-with-icon", target "_blank" ]
                    [ fa "external-link"
                    , text package.id
                    ]
                )

        Nothing ->
            Nothing


list : Int -> Int -> List ( String, Html msg ) -> Html msg
list colLabel colValue rows =
    let
        viewRow ( label, value ) =
            [ dt [ class <| "col-" ++ String.fromInt colLabel ]
                [ text label ]
            , dd [ class <| "col-" ++ String.fromInt colValue ]
                [ value ]
            ]
    in
    dl [ class "row" ] (List.concatMap viewRow rows)


viewOrganization : OrganizationInfo -> Html msg
viewOrganization organization =
    div [ class "organization" ]
        [ ItemIcon.view { text = organization.name, image = organization.logo }
        , div [ class "content" ]
            [ strong [] [ text organization.name ]
            , br [] []
            , text organization.organizationId
            ]
        ]


deleteVersionModal : AppState -> Model -> PackageDetail -> Html Msg
deleteVersionModal appState model package =
    let
        modalContent =
            [ p []
                (lh_ "deleteModal.message" [ strong [] [ text package.id ] ] appState)
            ]

        modalConfig =
            { modalTitle = l_ "deleteModal.title" appState
            , modalContent = modalContent
            , visible = model.showDeleteDialog
            , actionResult = model.deletingVersion
            , actionName = l_ "deleteModal.action" appState
            , actionMsg = DeleteVersion
            , cancelMsg = Just <| ShowDeleteDialog False
            , dangerous = True
            }
    in
    Modal.confirm modalConfig
