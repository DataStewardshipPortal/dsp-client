module KnowledgeModels.Models.Migration exposing (..)

import Json.Decode as Decode exposing (..)
import Json.Decode.Pipeline exposing (decode, optional, required)
import Json.Encode as Encode exposing (..)
import KnowledgeModels.Editor.Models.Entities exposing (KnowledgeModel, knowledgeModelDecoder)
import KnowledgeModels.Editor.Models.Events exposing (Event, eventDecoder)


type alias Migration =
    { branchUuid : String
    , migrationState : MigrationState
    , branchParentId : String
    , targetPackageId : String
    , currentKnowledgeModel : KnowledgeModel
    }


type alias MigrationState =
    { stateType : MigrationStateType
    , targetEvent : Maybe Event
    }


type MigrationStateType
    = ConflictState
    | ErrorState
    | CompletedState


type alias MigrationResolution =
    { originalEventUuid : String
    , action : String
    }


migrationDecoder : Decoder Migration
migrationDecoder =
    decode Migration
        |> required "branchUuid" Decode.string
        |> required "migrationState" migrationStateDecoder
        |> required "branchParentId" Decode.string
        |> required "targetPackageId" Decode.string
        |> required "currentKnowledgeModel" knowledgeModelDecoder


migrationStateDecoder : Decoder MigrationState
migrationStateDecoder =
    decode MigrationState
        |> required "type" migrationStateTypeDecoder
        |> optional "targetEvent" (Decode.maybe eventDecoder) Nothing


migrationStateTypeDecoder : Decoder MigrationStateType
migrationStateTypeDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "ConflictState" ->
                        Decode.succeed ConflictState

                    "ErrorState" ->
                        Decode.succeed ErrorState

                    "CompletedState" ->
                        Decode.succeed CompletedState

                    unknownStateType ->
                        Decode.fail <| "Unknown migration state type " ++ unknownStateType
            )


newMigrationResolution : String -> String -> MigrationResolution
newMigrationResolution action uuid =
    { originalEventUuid = uuid
    , action = action
    }


newAcceptMigrationResolution : String -> MigrationResolution
newAcceptMigrationResolution =
    newMigrationResolution "Accept"


newRejectMigrationResolution : String -> MigrationResolution
newRejectMigrationResolution =
    newMigrationResolution "Reject"


encodeMigrationResolution : MigrationResolution -> Encode.Value
encodeMigrationResolution data =
    Encode.object
        [ ( "originalEventUuid", Encode.string data.originalEventUuid )
        , ( "action", Encode.string data.action )
        , ( "event", Encode.null )
        ]
