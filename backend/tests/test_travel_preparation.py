from sqlalchemy import select
from sqlalchemy.orm import Session

from app.infrastructure.persistence.models import RouteModel


def test_preparation_is_published_only_and_refreshes_without_app_release(app, client):
    with Session(app.extensions["database"].engine, expire_on_commit=False) as db:
        route = db.scalar(select(RouteModel).where(RouteModel.slug == "nantou-time-layers"))
        route.travel_preparation = {
            "enabled": True,
            "admission": "ticket",
            "purchase_url": "https://official.example/tickets",
            "channel_name": "官方预约",
            "notices": "携带证件",
            "extra_items": [{"title": "接驳", "body": "南门上车", "url": ""}],
        }
        db.commit()
        slug = route.slug
        data = client.get(f"/api/v1/routes/{slug}").get_json()["data"]
        assert data["travel_preparation"]["extra_items"][0]["title"] == "接驳"
        assert "price" not in data["travel_preparation"]
        route.travel_preparation = {**route.travel_preparation, "notices": "提前预约"}
        db.commit()
        assert (
            client.get(f"/api/v1/routes/{slug}").get_json()["data"]["travel_preparation"]["notices"]
            == "提前预约"
        )
        route.travel_preparation = {**route.travel_preparation, "enabled": False}
        db.commit()
        assert client.get(f"/api/v1/routes/{slug}").get_json()["data"]["travel_preparation"] is None
        route.content_status = "draft"
        db.commit()
        assert client.get(f"/api/v1/routes/{slug}").status_code == 404
