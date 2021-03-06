module Common.FormEngine.Model exposing
    ( Form
    , FormElement(..)
    , FormElementState
    , FormItem(..)
    , FormItemDescriptor
    , FormTree
    , FormValue
    , FormValues
    , IntegrationReplyValue(..)
    , ItemElement
    , Option(..)
    , OptionDescriptor
    , OptionElement(..)
    , ReplyValue(..)
    , TypeHint
    , TypeHintConfig
    , TypeHints
    , createForm
    , createItemElement
    , decodeFormValues
    , decodeTypeHint
    , encodeFormValues
    , getAnswerUuid
    , getDescriptor
    , getFormValues
    , getItemListCount
    , getOptionDescriptor
    , getStringReply
    , isEmptyReply
    , setTypeHintsResult
    )

import ActionResult exposing (ActionResult)
import Debounce exposing (Debounce)
import Json.Decode as Decode exposing (..)
import Json.Decode.Extra exposing (when)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode exposing (..)
import List.Extra as List
import String exposing (fromInt)


type alias FormItemDescriptor question =
    { name : String
    , question : question
    }


type alias OptionDescriptor option =
    { name : String
    , option : option
    }


type Option question option
    = SimpleOption (OptionDescriptor option)
    | DetailedOption (OptionDescriptor option) (List (FormItem question option))


type alias TypeHintConfig =
    { logo : String
    , url : String
    }


type FormItem question option
    = StringFormItem (FormItemDescriptor question)
    | NumberFormItem (FormItemDescriptor question)
    | TextFormItem (FormItemDescriptor question)
    | TypeHintFormItem (FormItemDescriptor question) TypeHintConfig
    | ChoiceFormItem (FormItemDescriptor question) (List (Option question option))
    | GroupFormItem (FormItemDescriptor question) (List (FormItem question option))


type alias FormTree question option =
    { items : List (FormItem question option)
    }


type alias FormElementState =
    { value : Maybe ReplyValue
    , valid : Bool
    }


type OptionElement question option
    = SimpleOptionElement (OptionDescriptor option)
    | DetailedOptionElement (OptionDescriptor option) (List (FormElement question option))


type alias ItemElement question option =
    List (FormElement question option)


type FormElement question option
    = StringFormElement (FormItemDescriptor question) FormElementState
    | NumberFormElement (FormItemDescriptor question) FormElementState
    | TextFormElement (FormItemDescriptor question) FormElementState
    | TypeHintFormElement (FormItemDescriptor question) TypeHintConfig FormElementState
    | ChoiceFormElement (FormItemDescriptor question) (List (OptionElement question option)) FormElementState
    | GroupFormElement (FormItemDescriptor question) (List (FormItem question option)) (List (ItemElement question option)) FormElementState


type alias TypeHint =
    { id : String
    , name : String
    }


type alias TypeHints =
    { path : List String
    , hints : ActionResult (List TypeHint)
    }


type alias Form question option =
    { elements : List (FormElement question option)
    , typeHints : Maybe TypeHints
    , debounce : Debounce ( String, String )
    }


type ReplyValue
    = StringReply String
    | AnswerReply String
    | ItemListReply Int
    | EmptyReply
    | IntegrationReply IntegrationReplyValue


type IntegrationReplyValue
    = PlainValue String
    | IntegrationValue String String


type alias FormValues =
    List FormValue


type alias FormValue =
    { path : String
    , value : ReplyValue
    }



{- Decoders and encoders -}


decodeFormValues : Decoder FormValues
decodeFormValues =
    Decode.list decodeFormValue


decodeFormValue : Decoder FormValue
decodeFormValue =
    Decode.succeed FormValue
        |> required "path" Decode.string
        |> required "value" decodeReplyValue


decodeReplyValue : Decoder ReplyValue
decodeReplyValue =
    Decode.oneOf
        [ when replyValueType ((==) "StringReply") decodeStringReply
        , when replyValueType ((==) "AnswerReply") decodeAnswerReply
        , when replyValueType ((==) "ItemListReply") decodeItemListReply
        , when replyValueType ((==) "IntegrationReply") decodeIntegrationReply
        ]


replyValueType : Decoder String
replyValueType =
    Decode.field "type" Decode.string


decodeStringReply : Decoder ReplyValue
decodeStringReply =
    Decode.succeed StringReply
        |> required "value" Decode.string


decodeAnswerReply : Decoder ReplyValue
decodeAnswerReply =
    Decode.succeed AnswerReply
        |> required "value" Decode.string


decodeItemListReply : Decoder ReplyValue
decodeItemListReply =
    Decode.succeed ItemListReply
        |> required "value" Decode.int


decodeIntegrationReply : Decoder ReplyValue
decodeIntegrationReply =
    Decode.succeed IntegrationReply
        |> required "value" decodeIntegrationReplyValue


decodeIntegrationReplyValue : Decoder IntegrationReplyValue
decodeIntegrationReplyValue =
    Decode.oneOf
        [ when integrationValueType ((==) "PlainValue") decodePlainValue
        , when integrationValueType ((==) "IntegrationValue") decodeIntegrationValue
        ]


decodePlainValue : Decoder IntegrationReplyValue
decodePlainValue =
    Decode.succeed PlainValue
        |> required "value" Decode.string


decodeIntegrationValue : Decoder IntegrationReplyValue
decodeIntegrationValue =
    Decode.succeed IntegrationValue
        |> required "id" Decode.string
        |> required "value" Decode.string


integrationValueType : Decoder String
integrationValueType =
    Decode.field "type" Decode.string


decodeTypeHint : Decoder TypeHint
decodeTypeHint =
    Decode.succeed TypeHint
        |> required "id" Decode.string
        |> required "name" Decode.string


encodeFormValues : FormValues -> Encode.Value
encodeFormValues formValues =
    Encode.list encodeFormValue formValues


encodeFormValue : FormValue -> Encode.Value
encodeFormValue formValue =
    Encode.object
        [ ( "path", Encode.string formValue.path )
        , ( "value", encodeReplyValue formValue.value )
        ]


encodeReplyValue : ReplyValue -> Encode.Value
encodeReplyValue replyValue =
    case replyValue of
        StringReply string ->
            Encode.object
                [ ( "type", Encode.string "StringReply" )
                , ( "value", Encode.string string )
                ]

        AnswerReply uuid ->
            Encode.object
                [ ( "type", Encode.string "AnswerReply" )
                , ( "value", Encode.string uuid )
                ]

        ItemListReply count ->
            Encode.object
                [ ( "type", Encode.string "ItemListReply" )
                , ( "value", Encode.int count )
                ]

        EmptyReply ->
            Encode.null

        IntegrationReply integrationReplyValue ->
            case integrationReplyValue of
                PlainValue value ->
                    Encode.object
                        [ ( "type", Encode.string "IntegrationReply" )
                        , ( "value"
                          , Encode.object
                                [ ( "type", Encode.string "PlainValue" )
                                , ( "value", Encode.string value )
                                ]
                          )
                        ]

                IntegrationValue id value ->
                    Encode.object
                        [ ( "type", Encode.string "IntegrationReply" )
                        , ( "value"
                          , Encode.object
                                [ ( "type", Encode.string "IntegrationValue" )
                                , ( "id", Encode.string id )
                                , ( "value", Encode.string value )
                                ]
                          )
                        ]



{- Type helpers -}


getOptionDescriptor : OptionElement question option -> OptionDescriptor option
getOptionDescriptor option =
    case option of
        SimpleOptionElement descriptor ->
            descriptor

        DetailedOptionElement descriptor _ ->
            descriptor


getDescriptor : FormElement question option -> FormItemDescriptor question
getDescriptor element =
    case element of
        StringFormElement descriptor _ ->
            descriptor

        NumberFormElement descriptor _ ->
            descriptor

        TextFormElement descriptor _ ->
            descriptor

        ChoiceFormElement descriptor _ _ ->
            descriptor

        GroupFormElement descriptor _ _ _ ->
            descriptor

        TypeHintFormElement descriptor _ _ ->
            descriptor


getItemListCount : ReplyValue -> Int
getItemListCount replyValue =
    case replyValue of
        ItemListReply count ->
            count

        _ ->
            0


getAnswerUuid : ReplyValue -> String
getAnswerUuid replyValue =
    case replyValue of
        AnswerReply uuid ->
            uuid

        _ ->
            ""


getStringReply : ReplyValue -> String
getStringReply replyValue =
    case replyValue of
        StringReply string ->
            string

        IntegrationReply integrationReplyValue ->
            case integrationReplyValue of
                PlainValue value ->
                    value

                IntegrationValue id value ->
                    value

        _ ->
            ""


isEmptyReply : ReplyValue -> Bool
isEmptyReply replyValue =
    case replyValue of
        EmptyReply ->
            True

        _ ->
            False


setTypeHintsResult : ActionResult (List TypeHint) -> Form question option -> Form question option
setTypeHintsResult typeHintsResult form =
    let
        set result typeHints =
            { typeHints | hints = result }
    in
    { form | typeHints = Maybe.map (set typeHintsResult) form.typeHints }



{- Form creation -}


createForm : FormTree question option -> FormValues -> List String -> Form question option
createForm formTree formValues defaultPath =
    { elements = List.map createFormElement formTree.items |> List.map (setInitialValue formValues defaultPath)
    , typeHints = Nothing
    , debounce = Debounce.init
    }


createFormElement : FormItem question option -> FormElement question option
createFormElement item =
    case item of
        StringFormItem descriptor ->
            StringFormElement descriptor emptyFormElementState

        NumberFormItem descriptor ->
            NumberFormElement descriptor emptyFormElementState

        TextFormItem descriptor ->
            TextFormElement descriptor emptyFormElementState

        ChoiceFormItem descriptor options ->
            ChoiceFormElement descriptor (List.map createOptionElement options) emptyFormElementState

        GroupFormItem descriptor items ->
            GroupFormElement descriptor items [] emptyFormElementState

        TypeHintFormItem descriptor typeHintConfig ->
            TypeHintFormElement descriptor typeHintConfig emptyFormElementState


emptyFormElementState : FormElementState
emptyFormElementState =
    { value = Nothing, valid = True }


createOptionElement : Option question option -> OptionElement question option
createOptionElement option =
    case option of
        SimpleOption descriptor ->
            SimpleOptionElement descriptor

        DetailedOption descriptor items ->
            DetailedOptionElement descriptor (List.map createFormElement items)


createItemElement : List (FormItem question option) -> ItemElement question option
createItemElement formItems =
    List.map createFormElement formItems


setInitialValue : FormValues -> List String -> FormElement question option -> FormElement question option
setInitialValue formValues path element =
    case element of
        StringFormElement descriptor state ->
            StringFormElement descriptor { state | value = getInitialValue formValues path descriptor.name }

        NumberFormElement descriptor state ->
            NumberFormElement descriptor { state | value = getInitialValue formValues path descriptor.name }

        TextFormElement descriptor state ->
            TextFormElement descriptor { state | value = getInitialValue formValues path descriptor.name }

        ChoiceFormElement descriptor options state ->
            let
                newOptions =
                    List.map (setInitialValuesOption formValues (path ++ [ descriptor.name ])) options
            in
            ChoiceFormElement descriptor newOptions { state | value = getInitialValue formValues path descriptor.name }

        GroupFormElement descriptor items itemElements state ->
            let
                numberOfItems =
                    getInitialValue formValues path descriptor.name
                        |> Maybe.map getItemListCount
                        |> Maybe.withDefault 0

                newItemElements =
                    List.repeat numberOfItems (createItemElement items)
                        |> List.indexedMap (setInitialValuesItems formValues (path ++ [ descriptor.name ]))

                newState =
                    { state | value = Just <| ItemListReply numberOfItems }
            in
            GroupFormElement descriptor items newItemElements newState

        TypeHintFormElement descriptor typeHintConfig state ->
            TypeHintFormElement descriptor typeHintConfig { state | value = getInitialValue formValues path descriptor.name }


getInitialValue : FormValues -> List String -> String -> Maybe ReplyValue
getInitialValue formValues path current =
    let
        key =
            String.join "." (path ++ [ current ])
    in
    List.find (.path >> (==) key) formValues
        |> Maybe.map .value


setInitialValuesOption : FormValues -> List String -> OptionElement question option -> OptionElement question option
setInitialValuesOption formValues path option =
    case option of
        DetailedOptionElement descriptor items ->
            DetailedOptionElement descriptor (List.map (setInitialValue formValues (path ++ [ descriptor.name ])) items)

        _ ->
            option


setInitialValuesItems : FormValues -> List String -> Int -> ItemElement question option -> ItemElement question option
setInitialValuesItems formValues path index itemElement =
    List.map (setInitialValue formValues (path ++ [ fromInt index ])) itemElement



{- getting form values -}


getFormValues : List String -> Form question option -> FormValues
getFormValues defaultPath form =
    List.foldl (getFieldValue defaultPath) [] form.elements


getFieldValue : List String -> FormElement question option -> FormValues -> FormValues
getFieldValue path element values =
    case element of
        StringFormElement descriptor state ->
            applyFieldValue values (pathToKey path descriptor.name) state.value

        NumberFormElement descriptor state ->
            applyFieldValue values (pathToKey path descriptor.name) state.value

        TextFormElement descriptor state ->
            applyFieldValue values (pathToKey path descriptor.name) state.value

        ChoiceFormElement descriptor options state ->
            let
                newValues =
                    applyFieldValue values (pathToKey path descriptor.name) state.value
            in
            List.foldl (getOptionValues (path ++ [ descriptor.name ])) newValues options

        GroupFormElement descriptor items itemElements state ->
            let
                newValues =
                    applyFieldValue values (pathToKey path descriptor.name) state.value
            in
            List.indexedFoldl (getItemValues (path ++ [ descriptor.name ])) newValues itemElements

        TypeHintFormElement descriptor _ state ->
            applyFieldValue values (pathToKey path descriptor.name) state.value


getOptionValues : List String -> OptionElement question option -> FormValues -> FormValues
getOptionValues path option values =
    case option of
        DetailedOptionElement descriptor items ->
            List.foldl (getFieldValue (path ++ [ descriptor.name ])) values items

        _ ->
            values


getItemValues : List String -> Int -> ItemElement question option -> FormValues -> FormValues
getItemValues path index item values =
    List.foldl (getFieldValue (path ++ [ fromInt index ])) values item


pathToKey : List String -> String -> String
pathToKey path current =
    String.join "." (path ++ [ current ])


applyFieldValue : FormValues -> String -> Maybe ReplyValue -> FormValues
applyFieldValue values key replyValue =
    case replyValue of
        Just value ->
            values ++ [ { path = key, value = value } ]

        Nothing ->
            values ++ [ { path = key, value = EmptyReply } ]
