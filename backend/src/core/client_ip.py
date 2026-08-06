from __future__ import annotations

from ipaddress import (
    IPv4Address,
    IPv4Network,
    IPv6Address,
    IPv6Network,
    ip_address,
    ip_network,
)

from fastapi import Request

from src.core.config import settings


IPAddress = IPv4Address | IPv6Address
IPNetwork = IPv4Network | IPv6Network

_MAX_FORWARDED_HEADER_LENGTH = 2_048
_MAX_PROXY_HOPS = 20


# Ayarlardaki IP ve CIDR değerlerini ağ nesnelerine dönüştürür.
def build_trusted_proxy_networks(
    values: list[str],
) -> tuple[IPNetwork, ...]:
    return tuple(
        ip_network(value, strict=False)
        for value in values
    )


# Bir IP'nin güvenilir proxy ağlarından birinde olup olmadığını kontrol eder.
def is_trusted_proxy(
    address: IPAddress,
    networks: tuple[IPNetwork, ...],
) -> bool:
    return any(
        address.version == network.version
        and address in network
        for network in networks
    )


# Geçerli bir IP metnini standart IPv4 veya IPv6 biçimine dönüştürür.
def normalize_ip(value: str) -> IPAddress | None:
    normalized_value = value.strip()

    try:
        return ip_address(normalized_value)
    except ValueError:
        return None


# Doğrudan bağlantı ve proxy zincirinden gerçek istemci IP'sini bulur.
def resolve_client_ip(
    *,
    peer_host: str | None,
    x_forwarded_for: str | None,
    trusted_proxy_networks: tuple[IPNetwork, ...],
) -> str:
    if peer_host is None:
        return "unknown"

    peer_address = normalize_ip(peer_host)

    if peer_address is None:
        return "unknown"

    # Doğrudan bağlanan makine proxy değilse header tamamen yok sayılır.
    if not is_trusted_proxy(
        peer_address,
        trusted_proxy_networks,
    ):
        return peer_address.compressed

    if not x_forwarded_for:
        return peer_address.compressed

    if len(x_forwarded_for) > _MAX_FORWARDED_HEADER_LENGTH:
        return peer_address.compressed

    raw_hops = x_forwarded_for.split(",")

    if len(raw_hops) > _MAX_PROXY_HOPS:
        return peer_address.compressed

    forwarded_addresses: list[IPAddress] = []

    for raw_hop in raw_hops:
        address = normalize_ip(raw_hop)

        # Zincirin bir parçası bile bozuksa güvenli tarafa düşülür.
        if address is None:
            return peer_address.compressed

        forwarded_addresses.append(address)

    current_address = peer_address

    # Zincir sağdan sola yürünür; ilk güvenilmeyen adres istemcidir.
    for candidate in reversed(forwarded_addresses):
        if not is_trusted_proxy(
            current_address,
            trusted_proxy_networks,
        ):
            break

        current_address = candidate

    return current_address.compressed


# Middleware'in request state'e koyduğu güvenli istemci IP'sini döndürür.
def get_client_ip(request: Request) -> str:
    client_ip = getattr(
        request.state,
        "client_ip",
        None,
    )

    if isinstance(client_ip, str) and client_ip:
        return client_ip

    peer_host = (
        request.client.host
        if request.client is not None
        else None
    )

    return resolve_client_ip(
        peer_host=peer_host,
        x_forwarded_for=request.headers.get(
            "x-forwarded-for"
        ),
        trusted_proxy_networks=(
            build_trusted_proxy_networks(
                settings.TRUSTED_PROXY_IPS
            )
        ),
    )
# Gerçek IP çözümleyicisi dosya