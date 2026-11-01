import unittest
from pathlib import Path

from harness.loader import load_addon
from harness.wow_mock import WowRuntime

ADDON = Path(__file__).resolve().parents[1] / "addon" / "AHProbe"


def lua_list(table) -> list:
    """Convert a 1-based Lua array table to a Python list."""
    return [table[index] for index in range(1, len(table) + 1)]


class RetailClientTest(unittest.TestCase):
    def setUp(self):
        self.runtime = WowRuntime()
        self.files = load_addon(self.runtime, ADDON)
        self.runtime.fire("ADDON_LOADED", "AHProbe")
        self.ns = self.runtime.L.globals().AHProbeNS

    def test_toc_loads_every_lua_file_in_order(self):
        self.assertEqual(
            self.files,
            ["Core/Init.lua", "Core/Env.lua", "Core/Probe.lua", "UI/Main.lua"],
        )

    def test_detects_retail_client(self):
        self.assertTrue(self.ns.Env.IsModern())
        self.assertEqual(self.ns.Env.Flavor(), "retail")
        self.assertEqual(self.ns.Env.MaxLevel(), 90)
        self.assertEqual(self.ns.Env.FactionKey(), "")
        self.assertIsNotNone(self.runtime.L.globals().AuctionHouseFrame)

    def test_legacy_apis_are_absent(self):
        globals_ = self.runtime.L.globals()
        for name in (
            "QueryAuctionItems",
            "GetNumAuctionItems",
            "GetAuctionItemInfo",
            "PlaceAuctionBid",
            "AuctionFrame",
        ):
            self.assertIsNone(globals_[name], name)
        self.assertFalse(self.ns.Env.Has("QueryAuctionItems"))

    def test_realm_key_uses_connected_realm_not_character_realm(self):
        self.assertEqual(self.ns.Env.RealmKey(), "Alpha")

    def test_realm_key_can_use_a_ruleset(self):
        self.runtime.L.execute(
            "RegionalUniqueNamesEnabled = function() return true end\n"
            "C_GameRules = { IsGameRuleActive = function(id) return false end }\n"
            "Enum = { GameRule = { PvPRuleset = 1, RPRuleset = 2, HardcoreRuleset = 3 } }"
        )
        self.assertEqual(self.ns.Env.RealmKey(), "PvE")

        self.runtime.L.execute(
            "C_GameRules = { IsGameRuleActive = function(id) return id == 1 end }"
        )
        self.assertEqual(self.ns.Env.RealmKey(), "PvP")

    def test_capability_probe_reports_real_gaps(self):
        self.assertTrue(self.ns.Env.Cap("C_AuctionHouse.GetBrowseResults"))
        missing = lua_list(self.ns.Env.CapMissing())
        self.assertEqual(
            sorted(missing),
            sorted(
                [
                    "C_AuctionHouse.GetCommoditySearchResults",
                    "C_AuctionHouse.GetNumCommoditySearchResults",
                    "C_AuctionHouse.RequestMoreCommoditySearchResults",
                ]
            ),
        )

    def test_scan_sends_modern_browse_query(self):
        self.assertTrue(self.ns.Probe.Scan())
        queries = self.runtime.queries()
        self.assertEqual(len(queries), 1)
        self.assertEqual(queries[0], {})

        self.runtime.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        self.assertEqual(self.ns.Probe.count, 3)

    def test_scan_respects_the_throttle(self):
        self.runtime.L.execute(
            "C_AuctionHouse.IsThrottled = function() return true end"
        )
        self.assertFalse(self.ns.Probe.Scan())
        self.assertEqual(len(self.runtime.queries()), 0)
        self.assertIn("throttled", self.runtime.printed()[-1].lower())

    def test_legacy_event_is_not_registered_on_retail(self):
        fired = self.runtime.fire("AUCTION_ITEM_LIST_UPDATE")
        self.assertEqual(fired, 0)

    def test_ui_updates_after_results(self):
        self.runtime.fire("PLAYER_LOGIN")
        self.ns.Probe.Scan()
        self.runtime.fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        frame = self.runtime.L.globals().AHProbeFrame
        self.assertEqual(frame["countLabel"]["_text"], "Auctions: 3")

    def test_chinese_locale(self):
        runtime = WowRuntime(locale="zhCN")
        load_addon(runtime, ADDON)
        runtime.fire("ADDON_LOADED", "AHProbe")
        runtime.fire("PLAYER_LOGIN")
        frame = runtime.L.globals().AHProbeFrame
        self.assertEqual(frame["countLabel"]["_text"], "拍卖行条目: 0")

    def test_bag_info_normalizes_the_info_table(self):
        info = self.ns.Env.BagItemInfo(0, 1)
        self.assertEqual(info["itemID"], 203)
        self.assertEqual(info["stackCount"], 5)

        seen = []
        visited = self.ns.Env.ForEachBagSlot(lambda *args: seen.append(args))
        self.assertEqual(visited, 1)
        self.assertEqual(seen[0][0:2], (0, 1))

    def test_item_helpers_use_verified_indexes(self):
        self.assertEqual(self.ns.Env.ItemMaxStack(203), 20)
        self.assertEqual(self.ns.Env.ItemClassID(201), 2)
        self.assertEqual(self.ns.Env.ItemEquipLoc(201), "INVTYPE_WEAPON")
        self.assertEqual(
            self.ns.Env.ItemID("|cffffffff|Hitem:203::::::::|h[Item C]|h|r"), 203
        )


if __name__ == "__main__":
    unittest.main()
