module KMEditor.Editor2.TagEditor.Update exposing (update)

import KMEditor.Editor2.TagEditor.Models exposing (Model, addQuestionTag, removeQuestionTag)
import KMEditor.Editor2.TagEditor.Msgs exposing (Msg(..))


update : Msg -> Model -> Model
update msg model =
    case msg of
        Highlight tagUuid ->
            { model | highlightedTagUuid = Just tagUuid }

        CancelHighlight ->
            { model | highlightedTagUuid = Nothing }

        AddTag questionUuid tagUuid ->
            addQuestionTag model questionUuid tagUuid

        RemoveTag questionUuid tagUuid ->
            removeQuestionTag model questionUuid tagUuid