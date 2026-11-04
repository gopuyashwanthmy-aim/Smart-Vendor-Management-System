from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.address import Address
from app.models.notification import Notification

router = APIRouter(prefix="/customer", tags=["Customer"])
class ProfileUpdate(BaseModel):
    name: str = Field(min_length=2, max_length=100)

class AddressRequest(BaseModel):
    label: str = Field(default="Home", min_length=1, max_length=40)
    recipient_name: str = Field(min_length=2, max_length=100)
    phone: str = Field(min_length=10, max_length=20)
    address_line: str = Field(min_length=5, max_length=300)
    landmark: str | None = Field(default=None, max_length=200)
    city: str = Field(min_length=2, max_length=100)
    pincode: str = Field(min_length=4, max_length=12)
    is_default: bool = False

@router.get("/profile")
def get_profile(user: User = Depends(get_current_user)):
    return {"id": user.id, "name": user.name, "phone": user.phone, "role": user.role}

@router.put("/profile")
def update_profile(request: ProfileUpdate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    user.name = request.name.strip(); db.commit(); db.refresh(user)
    return {"id": user.id, "name": user.name, "phone": user.phone, "role": user.role}

@router.get("/addresses")
def list_addresses(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return db.query(Address).filter(Address.user_id == user.id).order_by(Address.is_default.desc(), Address.id.desc()).all()

@router.post("/addresses", status_code=status.HTTP_201_CREATED)
def create_address(request: AddressRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if request.is_default:
        db.query(Address).filter(Address.user_id == user.id).update({Address.is_default: False})
    address = Address(user_id=user.id, **request.model_dump())
    if not db.query(Address).filter(Address.user_id == user.id).first(): address.is_default = True
    db.add(address); db.commit(); db.refresh(address)
    return address

@router.put("/addresses/{address_id}")
def update_address(address_id: int, request: AddressRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    address = db.query(Address).filter(Address.id == address_id, Address.user_id == user.id).first()
    if not address: raise HTTPException(status_code=404, detail="Address not found")
    if request.is_default: db.query(Address).filter(Address.user_id == user.id).update({Address.is_default: False})
    for key, value in request.model_dump().items(): setattr(address, key, value)
    db.commit(); db.refresh(address)
    return address

@router.delete("/addresses/{address_id}")
def delete_address(address_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    address = db.query(Address).filter(Address.id == address_id, Address.user_id == user.id).first()
    if not address: raise HTTPException(status_code=404, detail="Address not found")
    db.delete(address); db.commit()
    return {"message": "Address deleted"}

@router.get("/notifications")
def list_notifications(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    rows = db.query(Notification).filter(Notification.user_id == user.id).order_by(Notification.created_at.desc()).limit(100).all()
    return rows

@router.get("/notifications/unread-count")
def unread_count(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return {"count": db.query(Notification).filter(Notification.user_id == user.id, Notification.is_read.is_(False)).count()}

@router.patch("/notifications/{notification_id}/read")
def mark_read(notification_id: int, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    row = db.query(Notification).filter(Notification.id == notification_id, Notification.user_id == user.id).first()
    if not row: raise HTTPException(status_code=404, detail="Notification not found")
    row.is_read = True; db.commit()
    return {"message": "Notification marked as read"}

@router.post("/notifications/read-all")
def mark_all_read(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    db.query(Notification).filter(Notification.user_id == user.id).update({Notification.is_read: True})
    db.commit()
    return {"message": "All notifications marked as read"}
