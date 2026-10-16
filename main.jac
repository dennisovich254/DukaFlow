import from ".components.ui.button" { Button }
import from ".components.ui.card" {
    Card, CardHeader, CardTitle, CardDescription, CardContent
}
import ".styles.global.css";

# Throwaway theme check (P0.5); replaced by the real layout in P1.
def:pub app() -> JsxElement {
    return <div className="wash-lime flex min-h-screen items-center justify-center p-6 text-foreground">
        <Card className="w-full max-w-md">
            <CardHeader>
                <CardTitle className="display text-3xl font-medium">DukaFlow theme check</CardTitle>
                <CardDescription>White, ink, lime wash, pill buttons.</CardDescription>
            </CardHeader>
            <CardContent className="flex gap-2">
                <Button>Get started</Button>
                <Button variant="outline">Docs</Button>
            </CardContent>
        </Card>
    </div>;
}
