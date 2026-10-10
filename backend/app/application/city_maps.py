from sqlalchemy import select

from app.infrastructure.persistence.models import CityMapModel, CityModel


def city_map_manifest(session, storage, slug):
    city = session.scalar(select(CityModel).where(CityModel.slug == slug))
    if city is None:
        return None
    row = session.get(CityMapModel, city.id)
    available = row is not None and row.object_key and row.version
    return {
        "status": "ready" if available else "pending",
        "adcode": row.adcode if row else None,
        "version": row.version if available else None,
        "url": storage.public_url(row.object_key) if available else None,
        "district_count": row.district_count if available else 0,
        "source": "DataV 地理数据",
    }
