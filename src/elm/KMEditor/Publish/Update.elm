module KMEditor.Publish.Update exposing (getKnowledgeModelCmd, update)

import Auth.Models exposing (Session)
import Common.Models exposing (getServerErrorJwt)
import Common.Types exposing (ActionResult(..))
import Form
import Jwt
import KMEditor.Models exposing (..)
import KMEditor.Publish.Models exposing (Model)
import KMEditor.Publish.Msgs exposing (Msg(..))
import KMEditor.Requests exposing (getKnowledgeModel, putKnowledgeModelVersion)
import KMPackages.Routing
import Msgs
import Requests exposing (toCmd)
import Routing exposing (Route(..), cmdNavigate)


getKnowledgeModelCmd : String -> Session -> Cmd Msgs.Msg
getKnowledgeModelCmd uuid session =
    getKnowledgeModel uuid session
        |> toCmd GetKnowledgeModelCompleted Msgs.KMEditorPublishMsg


putKnowledgeModelVersionCmd : Session -> KnowledgeModelPublishForm -> String -> Cmd Msgs.Msg
putKnowledgeModelVersionCmd session form uuid =
    let
        ( version, data ) =
            encodeKnowledgeModelPublishForm form
    in
    putKnowledgeModelVersion uuid version data session
        |> toCmd PutKnowledgeModelVersionCompleted Msgs.KMEditorPublishMsg


getKnowledgeModelCompleted : Model -> Result Jwt.JwtError KnowledgeModel -> ( Model, Cmd Msgs.Msg )
getKnowledgeModelCompleted model result =
    let
        newModel =
            case result of
                Ok knowledgeModel ->
                    { model | knowledgeModel = Success knowledgeModel }

                Err error ->
                    { model | knowledgeModel = getServerErrorJwt error "Unable to get the knowledge model." }
    in
    ( newModel, Cmd.none )


putKnowledgeModelVersionCompleted : Model -> Result Jwt.JwtError String -> ( Model, Cmd Msgs.Msg )
putKnowledgeModelVersionCompleted model result =
    case result of
        Ok version ->
            ( model, cmdNavigate (KMPackages KMPackages.Routing.Index) )

        Err error ->
            ( { model | publishingKnowledgeModel = getServerErrorJwt error "Publishing new version failed" }, Cmd.none )


handleForm : Form.Msg -> Session -> Model -> ( Model, Cmd Msgs.Msg )
handleForm formMsg session model =
    case ( formMsg, Form.getOutput model.form, model.knowledgeModel ) of
        ( Form.Submit, Just form, Success km ) ->
            let
                cmd =
                    putKnowledgeModelVersionCmd session form km.uuid
            in
            ( { model | publishingKnowledgeModel = Loading }, cmd )

        _ ->
            let
                form =
                    Form.update knowledgeModelPublishFormValidation formMsg model.form
            in
            ( { model | form = form }, Cmd.none )


update : Msg -> Session -> Model -> ( Model, Cmd Msgs.Msg )
update msg session model =
    case msg of
        GetKnowledgeModelCompleted result ->
            getKnowledgeModelCompleted model result

        FormMsg msg ->
            handleForm msg session model

        PutKnowledgeModelVersionCompleted result ->
            putKnowledgeModelVersionCompleted model result