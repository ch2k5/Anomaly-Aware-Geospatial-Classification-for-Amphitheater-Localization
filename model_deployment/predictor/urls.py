from . import views
from django.urls import path,include

urlpatterns = [
    path('predict/', views.predict)
]