module Main exposing (..)

import Html exposing (Html, Attribute, a, div, hr, input, span, text)
import Html.App exposing (map)
import Navigation
import Pair
import Account
import Config
import NavBar exposing (..)
import UrlParser exposing (..)
import Result exposing (withDefault)
import String
import Html.Attributes exposing (class)
import Navigation exposing (newUrl)
import CoreTypes exposing (Msg(..), Page(..), Category)


main : Program Never
main =
    Navigation.program (Navigation.makeParser pageParser)
        { init = init
        , view = view
        , update = update
        , urlUpdate = urlUpdate
        , subscriptions = subscriptions
        }



-- URL PARSERS


pageParser : Navigation.Location -> Result String Page
pageParser location =
    UrlParser.parse identity desiredPage (String.dropLeft 1 location.pathname)


desiredPage : Parser (Page -> a) a
desiredPage =
    oneOf
        [ format (\account -> AccountPage account) (s "account" </> string)
        , format PairPage (s "pair")
        , format (\config crypto -> ConfigPage config (Just crypto)) (s "config" </> string </> string)
        , format (\config -> ConfigPage config Nothing) (s "config" </> string)
        ]



-- MODEL


type alias Model =
    { page : Page
    , category : Maybe Category
    , pair : Pair.Model
    , account : Account.Model
    , config : Config.Model
    , err : Maybe String
    }


init : Result String Page -> ( Model, Cmd Msg )
init pageResult =
    let
        initModel =
            { page = withDefault UnknownPage (Debug.log "DEBUG11" pageResult)
            , category = Nothing
            , account = Account.init
            , pair = Pair.init
            , config = Config.init
            , err = Nothing
            }
    in
        urlUpdate pageResult initModel



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PairMsg pairMsg ->
            let
                ( pairModel, cmd ) =
                    Pair.update pairMsg model.pair
            in
                { model | pair = pairModel } ! [ Cmd.map PairMsg cmd ]

        AccountMsg accountMsg ->
            let
                ( accountModel, cmd ) =
                    Account.update accountMsg model.account
            in
                { model | account = accountModel } ! [ Cmd.map AccountMsg cmd ]

        ConfigMsg configMsg ->
            let
                ( configModel, cmd ) =
                    Config.update configMsg model.config
            in
                { model | config = configModel } ! [ Cmd.map ConfigMsg cmd ]

        NewPage maybeCategory page ->
            let
                url =
                    NavBar.pageToUrl page
            in
                { model | category = maybeCategory } ! [ newUrl url ]


content : Model -> Html Msg
content model =
    case model.page of
        PairPage ->
            map PairMsg (Pair.view model.pair)

        AccountPage _ ->
            map AccountMsg (Account.view model.account)

        ConfigPage _ _ ->
            map ConfigMsg (Config.view model.config)

        UnknownPage ->
            div [] [ text ("No such page") ]


view : Model -> Html Msg
view model =
    div []
        [ div [ class "grid" ]
            [ div [ class "unit one-quarter no-gutters lamassuAdminMainLeft" ]
                [ NavBar.view model.category model.page ]
            , div [ class "unit three-quarters lamassuAdminMainRight" ]
                [ div [ class "lamassuAdminContent" ]
                    [ content model ]
                ]
            ]
        ]


urlUpdate : Result String Page -> Model -> ( Model, Cmd Msg )
urlUpdate pageResult model =
    let
        pagedModel =
            { model | page = withDefault UnknownPage pageResult }
    in
        case Debug.log "result" pageResult of
            Err updateErr ->
                { model | err = Just updateErr } ! []

            Ok page ->
                case page of
                    PairPage ->
                        let
                            ( pairModel, cmd ) =
                                Pair.load
                        in
                            { pagedModel | pair = pairModel } ! [ Cmd.map PairMsg cmd ]

                    AccountPage account ->
                        let
                            ( accountModel, cmd ) =
                                Account.load account
                        in
                            { pagedModel | account = accountModel } ! [ Cmd.map AccountMsg cmd ]

                    ConfigPage config maybeCryptoCodeString ->
                        let
                            ( configModel, cmd ) =
                                Config.load pagedModel.config config maybeCryptoCodeString
                        in
                            { pagedModel | config = configModel } ! [ Cmd.map ConfigMsg cmd ]

                    UnknownPage ->
                        Debug.crash "Need to create unknown page"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
