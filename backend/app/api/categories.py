from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_admin
from app.models.category import Category
from app.models.user import User

router = APIRouter(prefix="/categories", tags=["Categories"])
class CategoryRequest(BaseModel):
    name: str = Field(min_length=2, max_length=50)

@router.get("/")
def list_categories(db: Session = Depends(get_db)):
    return db.query(Category).order_by(Category.name.asc()).all()

@router.post("/", status_code=status.HTTP_201_CREATED)
def create_category(request: CategoryRequest, db: Session = Depends(get_db), admin: User = Depends(get_current_admin)):
    name = request.name.strip()
    if db.query(Category).filter(Category.name.ilike(name)).first():
        raise HTTPException(status_code=409, detail="Category already exists")
    category = Category(name=name)
    db.add(category); db.commit(); db.refresh(category)
    return category

@router.put("/{category_id}")
def update_category(category_id: int, request: CategoryRequest, db: Session = Depends(get_db), admin: User = Depends(get_current_admin)):
    category = db.query(Category).filter(Category.id == category_id).first()
    if not category: raise HTTPException(status_code=404, detail="Category not found")
    name = request.name.strip()
    duplicate = db.query(Category).filter(Category.name.ilike(name), Category.id != category_id).first()
    if duplicate: raise HTTPException(status_code=409, detail="Category already exists")
    category.name = name; db.commit(); db.refresh(category)
    return category

@router.delete("/{category_id}")
def delete_category(category_id: int, db: Session = Depends(get_db), admin: User = Depends(get_current_admin)):
    category = db.query(Category).filter(Category.id == category_id).first()
    if not category: raise HTTPException(status_code=404, detail="Category not found")
    from app.models.product import Product
    if db.query(Product).filter(Product.category_id == category_id).first():
        raise HTTPException(status_code=409, detail="Move or delete products in this category first")
    db.delete(category); db.commit()
    return {"message": "Category deleted"}
