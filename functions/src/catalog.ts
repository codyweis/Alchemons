/**
 * Server-side product catalog.
 *
 * This is the ONLY source of truth for how much gold a product grants. The
 * client sends a product id and a store receipt; it never sends an amount.
 * Keep this in sync with `_catalog` in lib/services/mobile_store_service.dart.
 */
export interface GoldPack {
  readonly productId: string;
  readonly goldAmount: number;
}

const PACKS: readonly GoldPack[] = [
  {productId: "alchemons_gold_cache", goldAmount: 25},
  {productId: "alchemons_gold_stash", goldAmount: 75},
  {productId: "alchemons_gold_vault", goldAmount: 200},
  {productId: "alchemons_gold_celestial", goldAmount: 500},
];

const BY_ID = new Map(PACKS.map((pack) => [pack.productId, pack]));

/** Returns the pack for [productId], or null if it is not a known product. */
export function goldPackFor(productId: string): GoldPack | null {
  return BY_ID.get(productId) ?? null;
}

/** Android application id, used when verifying Play purchase tokens. */
export const ANDROID_PACKAGE_NAME = "com.luck3yapps.alchemons";
