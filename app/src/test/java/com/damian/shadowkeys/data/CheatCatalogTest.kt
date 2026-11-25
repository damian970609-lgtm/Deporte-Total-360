package com.damian.shadowkeys.data

import com.damian.shadowkeys.input.InputKeyMapper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CheatCatalogTest {
    @Test
    fun mobileCatalogContainsTheExact83CodesFromTheMobileList() {
        val expectedCodes = setOf(
            "PJYNQCQ", "BLOKKIK", "SLOTSFK", "AESHXWQI", "SGVDSQW", "AWXDCRJ",
            "MTGIISR", "APGZLQR", "AEZLCKXU", "POOOJOX", "KBTMUVH", "GONPXWR",
            "BEFWKSBQ", "SHHIHJG", "GOIZSSX", "NECUMZ", "RYSMRM", "BIEUHQY",
            "CDGUDEP", "GSUMLEG", "AYNVQVK", "AWPTMIIQ", "BIGLWCDD", "BGJPSYC",
            "BIEAVBAY", "HPGPIJZ", "PSPNATX", "IXSMWCQ", "QPOLSVK", "DAHESZY",
            "BXBTUBTI", "BKFONFE", "DLNNHZJ", "WUSDOTO", "DOTBSFK", "PTHSEO",
            "BDBGXNJI", "JBVIJXA", "TDBKCEH",
            "BYKGOAB", "NCBXXDX", "KDTZNHO", "GWJZWC",
            "ENQCFMA", "IOKXTFJ", "GOYDVAO", "GYKVYTR", "FRIUBIL", "JTBCSN",
            "DEHDRX", "NJXPCYE", "AKOZBCH", "FARYJHZ", "ERFBFNI", "GDNXHDK",
            "EAMLJNN", "HAPOHXR",
            "AAEXPPQC", "HTRTTVJ", "VBWEMQX", "TAVPIER", "EAKILHM", "EGCEBVM",
            "JBWDWWO", "KTGDLXY", "AWUJNBB", "OWAKIJ", "YACKMWS",
            "LRMYOJM", "BFMANNZP", "SLSNRKK", "BWCMMTD", "HDLIWGB", "BNIZWSB",
            "OAXCCRI", "AAUSQP", "LNHVOAE", "JEZRPI", "AWIOMPH", "QAONHOH",
            "EHWBWDS", "FNJFCZC", "BYIXZIY"
        )

        assertEquals(83, CheatCatalog.all.size)
        assertEquals(83, CheatCatalog.all.map { it.code }.distinct().size)
        assertEquals(expectedCodes, CheatCatalog.all.map { it.code }.toSet())
    }

    @Test
    fun everyCatalogCodeCanBeConvertedToAndroidKeyCodes() {
        CheatCatalog.all.forEach { cheat ->
            assertNotNull("${cheat.title}: ${cheat.code}", InputKeyMapper.toKeyCodes(cheat.code))
        }
    }

    @Test
    fun knownMobileCodeMapsToTheExpectedAndroidKeyEvents() {
        assertEquals(
            listOf(44, 38, 53, 42, 45, 31, 45),
            InputKeyMapper.toKeyCodes("PJYNQCQ")?.toList()
        )
        assertEquals(
            listOf(7, 16, 29),
            InputKeyMapper.toKeyCodes("01A")?.toList()
        )
    }

    @Test
    fun categoriesContainExpectedCounts() {
        assertEquals(12, CheatCatalog.all.count { it.category == CheatCatalog.PLAYER })
        assertEquals(6, CheatCatalog.all.count { it.category == CheatCatalog.WEAPONS })
        assertEquals(21, CheatCatalog.all.count { it.category == CheatCatalog.VEHICLES })
        assertEquals(4, CheatCatalog.all.count { it.category == CheatCatalog.WANTED })
        assertEquals(14, CheatCatalog.all.count { it.category == CheatCatalog.WORLD })
        assertEquals(11, CheatCatalog.all.count { it.category == CheatCatalog.WEATHER })
        assertEquals(15, CheatCatalog.all.count { it.category == CheatCatalog.FUN })
    }

    @Test
    fun searchFiltersByTitleCodeAndCategory() {
        assertEquals("PJYNQCQ", CheatCatalog.search("250 000", null).single().code)
        assertEquals("CDGUDEP", CheatCatalog.search("jetpack", null).single().code)
        assertTrue(CheatCatalog.search("", CheatCatalog.WANTED).all { it.category == CheatCatalog.WANTED })
    }

    @Test
    fun mapperRejectsUnsupportedCharacters() {
        assertEquals(null, InputKeyMapper.toKeyCodes("BAD CODE"))
        assertEquals(null, InputKeyMapper.toKeyCodes(""))
    }
}
