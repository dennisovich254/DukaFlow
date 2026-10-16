"""Domain error carrying a stable error code, so clients never see raw exceptions."""

obj DomainError(Exception) {
    has code: str,
        message: str;

    def __str__ -> str {
        return f"{self.code}: {self.message}";
    }
}
