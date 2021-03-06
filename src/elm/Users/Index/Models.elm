module Users.Index.Models exposing (Model, initialModel)

import ActionResult exposing (ActionResult(..))
import Users.Common.User exposing (User)


type alias Model =
    { users : ActionResult (List User)
    , userToBeDeleted : Maybe User
    , deletingUser : ActionResult String
    }


initialModel : Model
initialModel =
    { users = Loading
    , userToBeDeleted = Nothing
    , deletingUser = Unset
    }
