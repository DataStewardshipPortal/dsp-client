module KnowledgeModels.Detail.Update exposing (fetchData, update)

import ActionResult exposing (ActionResult(..))
import Auth.Models exposing (Session)
import Bootstrap.Dropdown as Dropdown
import Common.Models exposing (getServerErrorJwt)
import Jwt
import KnowledgeModels.Common.Models exposing (PackageDetail)
import KnowledgeModels.Detail.Models exposing (..)
import KnowledgeModels.Detail.Msgs exposing (Msg(..))
import KnowledgeModels.Requests exposing (..)
import KnowledgeModels.Routing exposing (Route(..))
import Models exposing (State)
import Msgs
import Requests exposing (getResultCmd)
import Routing exposing (Route(..), cmdNavigate)


fetchData : (Msg -> Msgs.Msg) -> String -> String -> Session -> Cmd Msgs.Msg
fetchData wrapMsg organizationId kmId session =
    getPackagesFiltered organizationId kmId session
        |> Jwt.send GetPackageCompleted
        |> Cmd.map wrapMsg


update : Msg -> (Msg -> Msgs.Msg) -> State -> Model -> ( Model, Cmd Msgs.Msg )
update msg wrapMsg state model =
    case msg of
        GetPackageCompleted result ->
            getPackageCompleted model result

        ShowHideDeleteVersion version ->
            ( { model | versionToBeDeleted = version, deletingVersion = Unset }, Cmd.none )

        DeleteVersion ->
            handleDeleteVersion wrapMsg state.session model

        DeleteVersionCompleted result ->
            deleteVersionCompleted state model result

        DropdownMsg packageDetail dropdownState ->
            handleDropdownToggle model packageDetail dropdownState


getPackageCompleted : Model -> Result Jwt.JwtError (List PackageDetail) -> ( Model, Cmd Msgs.Msg )
getPackageCompleted model result =
    let
        newModel =
            case result of
                Ok packages ->
                    { model | packages = Success <| List.map initPackageDetailRow packages }

                Err error ->
                    { model | packages = getServerErrorJwt error "Unable to get package detail" }

        cmd =
            getResultCmd result
    in
    ( newModel, cmd )


handleDeleteVersion : (Msg -> Msgs.Msg) -> Session -> Model -> ( Model, Cmd Msgs.Msg )
handleDeleteVersion wrapMsg session model =
    case ( currentPackage model, model.versionToBeDeleted ) of
        ( Just package, Just version ) ->
            ( { model | deletingVersion = Loading }
            , deletePackageVersionCmd wrapMsg version session
            )

        _ ->
            ( model, Cmd.none )


deletePackageVersionCmd : (Msg -> Msgs.Msg) -> String -> Session -> Cmd Msgs.Msg
deletePackageVersionCmd wrapMsg packageId session =
    deletePackageVersion packageId session
        |> Jwt.send DeleteVersionCompleted
        |> Cmd.map wrapMsg


deleteVersionCompleted : State -> Model -> Result Jwt.JwtError String -> ( Model, Cmd Msgs.Msg )
deleteVersionCompleted state model result =
    case result of
        Ok version ->
            let
                route =
                    case ( packagesLength model > 1, currentPackage model ) of
                        ( True, Just package ) ->
                            KnowledgeModels <| Detail package.organizationId package.kmId

                        _ ->
                            KnowledgeModels Index
            in
            ( model, cmdNavigate state.key route )

        Err error ->
            ( { model
                | deletingVersion = getServerErrorJwt error "Version could not be deleted"
              }
            , getResultCmd result
            )


handleDropdownToggle : Model -> PackageDetail -> Dropdown.State -> ( Model, Cmd Msgs.Msg )
handleDropdownToggle model packageDetail state =
    case model.packages of
        Success packageDetailRows ->
            let
                replaceWith row =
                    if row.packageDetail == packageDetail then
                        { row | dropdownState = state }

                    else
                        row

                newRows =
                    List.map replaceWith packageDetailRows
            in
            ( { model | packages = Success newRows }, Cmd.none )

        _ ->
            ( model, Cmd.none )