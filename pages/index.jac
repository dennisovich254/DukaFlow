import from "@jac/runtime" { Navigate, jacIsLoggedIn }

"""Root: signed-in users go to the dashboard, everyone else to the login (landing page comes in P7)."""
def:pub Home() -> JsxPage {
    if jacIsLoggedIn() {
        return <Navigate to="/dashboard" replace={True} />;
    }
    return <Navigate to="/login" replace={True} />;
}
