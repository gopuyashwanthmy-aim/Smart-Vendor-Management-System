from pydantic import BaseModel, ConfigDict, Field


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    phone: str = Field(min_length=10, max_length=15, pattern=r"^[0-9+ -]+$")
    password: str = Field(min_length=8, max_length=128)


class LoginRequest(BaseModel):
    phone: str = Field(min_length=10, max_length=15, pattern=r"^[0-9+ -]+$")
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    id: int
    name: str
    phone: str
    role: str

    model_config = ConfigDict(from_attributes=True)
