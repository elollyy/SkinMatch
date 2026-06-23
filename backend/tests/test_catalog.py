from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import backend.app.catalog as catalog_module


class CatalogLoaderTest(unittest.TestCase):
    def test_load_catalog_reads_utf8_sig_and_builds_placeholder_url(self) -> None:
        contents = (
            "Предназночение;Бренд;Название продукта;Ценовой сегмент;"
            "Возрастная категория;Ингредиенты;Тип состава;Комбинированная;"
            "Сухая кожа;Нормальная;Жирная;Чувствительная;Проблемная кожа;"
            "Универсальность;Оценка;Категория эффективности;Кластер;split\n"
            "Очищение;Бренд Тест;Пенка;Средний;25+;вода, ароматизатор.;"
            "Смешанный;1;0;1;0;0;0;0;4,5;Высокая;Группа1;train\n"
        )

        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "catalog.csv"
            path.write_text(contents, encoding="utf-8-sig")

            result = catalog_module.load_catalog(path)

        self.assertEqual(result.invalid_rows, 0)
        self.assertEqual(len(result.products), 1)
        self.assertEqual(result.products[0].brand, "Бренд Тест")
        self.assertEqual(result.products[0].price_segment, "Средний")
        self.assertEqual(result.products[0].rating, 4.5)
        self.assertTrue(
            result.products[0].url.startswith("https://example.com/products/")
        )

    def test_load_catalog_reads_utf8_sig_without_pandas(self) -> None:
        contents = (
            "Предназночение;Бренд;Название продукта;Ценовой сегмент;"
            "Возрастная категория;Ингредиенты;Тип состава;Комбинированная;"
            "Сухая кожа;Нормальная;Жирная;Чувствительная;Проблемная кожа;"
            "Универсальность;Оценка;Категория эффективности;Кластер;split\n"
            "Увлажнение;Бренд Фолбэк;Крем;Высокий;30+;вода, глицерин.;"
            "Натуральный;1;1;1;0;0;0;0;4,9;Средняя;Группа2;test\n"
        )

        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "catalog.csv"
            path.write_text(contents, encoding="utf-8-sig")

            original_pandas = catalog_module.pd
            catalog_module.pd = None
            try:
                result = catalog_module.load_catalog(path)
            finally:
                catalog_module.pd = original_pandas

        self.assertEqual(result.invalid_rows, 0)
        self.assertEqual(len(result.products), 1)
        self.assertEqual(result.products[0].brand, "Бренд Фолбэк")
        self.assertEqual(result.products[0].rating, 4.9)
