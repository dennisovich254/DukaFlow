import from "@jac/runtime" { Navigate, jacIsLoggedIn }
import from ..components.landing.Landing { Landing }

"""Root: signed-in wholesalers go to the dashboard, everyone else sees the landing page."""
def:pub Home() -> JsxPage {
    if jacIsLoggedIn() {
        return <Navigate to="/dashboard" replace={True} />;
    }
    return <Landing />;
}
