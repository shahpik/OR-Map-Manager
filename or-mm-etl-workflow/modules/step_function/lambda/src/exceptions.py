class MissingParamException(ValueError):
    def __init__(self, param_name, error_message="Required parameter is missing - {}"):
        self.param_name = param_name
        self.error_message = error_message.format(param_name)
        super().__init__(self.error_message)


class ValidationException(ValueError):
    def __init__(self, error_message="Parameter validation failed"):
        super().__init__(error_message)
