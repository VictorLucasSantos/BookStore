import json

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient, APITestCase

from order.factories import OrderFactory, UserFactory
from order.models import Order
from product.factories import CategoryFactory, ProductFactory


class TestOrderViewSet(APITestCase):

    client = APIClient()

    def setUp(self):
        self.category = CategoryFactory(title="tecnology")
        self.product = ProductFactory(
            title="laptop", price=100, category=[self.category]
        )
        self.order = OrderFactory(product=[self.product])

    def test_order(self):
        response = self.client.get(
            reverse("order-list", kwargs={"version": "v1"}))

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        order_data = json.loads(response.content)

        self.assertEqual(order_data["product"][0]["title"], self.product.title)
        self.assertEqual(order_data["product"][0]["price"], self.product.price)
        self.assertEqual(order_data["product"][0]["active"], self.product.active)
        self.assertEqual(order_data["product"][0]["category"][0]["title"], self.product.category.title,
        )

    def test_create_order(self):
        user = UserFactory()
        product = ProductFactory()
        data = json.dumps(
            {
                "product": [self.product.id],
                "user": self.order.user.id,
            }
        )

        response = self.client.post(
            reversed("order-list"),
            kwargs={"version": "v1"},
            data=data,
            content_type="application/json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        created_order = Order.objects.get(user=user)
