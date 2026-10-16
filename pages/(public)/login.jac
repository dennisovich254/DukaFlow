import from "@jac/runtime" { jacLogin, jacSignup, SignupResult, useNavigate, Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Asterisk02Icon }
import from ...components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }
import from ...components.ui.field { Field, FieldLabel, FieldGroup }
import from ...components.ui.input { Input }
import from ...components.ui.button { Button }
import from ...components.ui.alert { Alert, AlertDescription }

"""Wholesaler sign-in and first-time account creation."""
def:pub LoginPage() -> JsxPage {
    has email: str = "";
    has password: str = "";
    has creating: bool = False;
    has busy: bool = False;
    has error: str = "";
    nav = useNavigate();

    async def submit(e: FormEvent) {
        e.preventDefault();
        busy = True;
        error = "";
        signup: SignupResult | None = None;
        ok: bool = False;
        try {
            if creating {
                signup = await jacSignup(email, password);
                if not signup.success {
                    error = signup.error or "Could not create the account.";
                    busy = False;
                    return;
                }
            }
            ok = await jacLogin(email, password);
            if ok {
                nav("/dashboard", {"replace": True});
            } else {
                error = "Wrong email or password.";
            }
        } except Exception {
            error = "Could not reach the server. Try again.";
        }
        busy = False;
    }

    def toggle_mode(e: MouseEvent) {
        creating = not creating;
        error = "";
    }

    <div className="wash-lime relative flex min-h-svh items-center justify-center pt-20 pb-12 pl-4 pr-4">
        <Link to="/" className="absolute top-6 left-6 flex items-center gap-2 text-lg font-semibold tracking-tight">
            <HugeiconsIcon icon={Asterisk02Icon} strokeWidth={2.5} className="size-7" />
            DukaFlow
        </Link>
        <Card className="w-full max-w-sm rounded-3xl shadow-xl">
            <CardHeader>
                <CardTitle className="display text-3xl font-medium">{"Create your account" if creating else "Welcome back"}</CardTitle>
                <CardDescription>
                    {"Set up your wholesale business." if creating else "Sign in to manage orders and stock."}
                </CardDescription>
            </CardHeader>
            <CardContent>
                <form className="flex flex-col gap-6" onSubmit={submit}>
                    <FieldGroup>
                        <Field>
                            <FieldLabel htmlFor="email">Email</FieldLabel>
                            <Input id="email" type="email" autoComplete="email" required={True}
                                value={email} onChange={lambda (e: ChangeEvent) { email = e.target.value; }} />
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="password">Password</FieldLabel>
                            <Input id="password" type="password" required={True}
                                autoComplete={"new-password" if creating else "current-password"}
                                value={password} onChange={lambda (e: ChangeEvent) { password = e.target.value; }} />
                        </Field>
                    </FieldGroup>
                    {error and <Alert variant="destructive"><AlertDescription>{error}</AlertDescription></Alert>}
                    <Button type="submit" className="h-11 w-full" disabled={busy}>
                        {"Please wait…" if busy else ("Create account" if creating else "Sign in")}
                    </Button>
                </form>
            </CardContent>
            <CardFooter>
                <p className="w-full text-center text-sm text-muted-foreground">
                    {"Already have an account?" if creating else "New to DukaFlow?"}{" "}
                    <button type="button" className="cursor-pointer text-foreground underline-offset-4 hover:underline" onClick={toggle_mode}>
                        {"Sign in" if creating else "Create an account"}
                    </button>
                </p>
            </CardFooter>
        </Card>
    </div>
}
