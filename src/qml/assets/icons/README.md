# Restaurant Management Backend (Go)

A REST API for a multi-restaurant management platform: restaurant owners manage
their menu and branding<!-- , and QR codes -->; the platform admin manages premium
subscriptions.

## Stack

- **Gin** — HTTP router
- **GORM + PostgreSQL** — ORM / database
- **JWT** — auth
- **bcrypt** — password hashing
<!-- - **go-qrcode** — QR image generation

## Getting started

**Requires Go 1.22+ and PostgreSQL.** Dependency downloads need normal internet
access (this was built in a sandbox without access to the Go module proxy, so
run these steps on your own machine):

```bash
cp .env.example .env        # then edit DATABASE_URL / JWT_SECRET
go mod tidy                 # downloads dependencies
go run main.go
```

The server starts on `:8080` (configurable via `PORT`). Tables are
auto-migrated on startup — make sure the Postgres database in `DATABASE_URL`
already exists. -->

## Schema

| Entity           | Fields                                                                                                                                                                                 |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **User**         | FullName, Email, Password, Role (`super_admin` / `restaurant_owner` / `staff`), CreatedAt                                                                                              |
| **Restaurant**   | NameEn/NameAm, CustomSubLink, Logo, Banner, Slogan, Images (3 free / 6 premium), LongerDescription, Location/Phone/OpenHours, AvailableLocations, FoodSpecifications — owned by a User |
| **Category**     | Name — belongs to a Restaurant                                                                                                                                                         |
| **Food**         | Name, Price, RatingAmount/Count, Tag, Description, Ingredients, Pic, PrepTime, Calories, BestPairings, IsSpicy — belongs to a Category                                                 |
| **Comment**      | AuthorName, Rating, Message, Time — belongs to a Food                                                                                                                                  |
| **Subscription** | Plan (`free`/`premium`), JoinTime, LastPaymentRenewal, LastRenewal, ExpiresAt — one per Restaurant                                                                                     |
<!-- | **QRCode**       | TableID (optional), RestaurantName, ImageURL — belongs to a Restaurant                                                                                                                 | -->


## For `POST` and `PUT` requests, their required body is under each table

# API Routes

**Base URL:** `<BaseEndpoint>/api/v1`

### Auth

| Method | Path             | Notes                                   |
| ------ | ---------------- | --------------------------------------- |
| POST   | `/auth/register` | Creates a `restaurant_owner` by default |
| POST   | `/auth/login`    | Returns a JWT                           |

### POST `/auth/register`

```json
{
  "full_name": "somebody",
  "email": "none@example.com",
  "password": "password123",
  "role": "restaurant_owner"
}
```

### POST `/auth/login`

```json
{
  "email": "none@example.com",
  "password": "password123"
}
```

### Public (no auth — customer-facing)

| Method | Path                                                           | Notes                                                                 |
| ------ | -------------------------------------------------------------- | --------------------------------------------------------------------- |
| GET    | `/public/restaurants`                                          | Lists publicly available restaurants                                  |
| GET    | `/public/restaurants/:id`                                      | Gets restaurant details/menu; `:id` accepts UUID or `custom_sub_link` |
| GET    | `/public/restaurants/:id/categories`                           | Lists categories for a restaurant                                     |
| GET    | `/public/restaurants/:id/categories/:categoryId/foods`         | Lists foods in a category                                             |
| GET    | `/public/restaurants/:id/categories/:categoryId/foods/:foodId` | Gets details for a specific food                                      |
| POST   | `/public/foods/:foodId/comments`                               | Adds a comment to a food item                                         |

### POST `/public/foods/:foodId/comments`

```json
{
  "author_name": "somebody",
  "rating": 5,
  "message": "Excellent food!"
}
```

### User Profile (JWT required)

| Method | Path            | Notes                                                  |
| ------ | --------------- | ------------------------------------------------------ |
| GET    | `/user/profile` | Returns the authenticated user's profile               |
| PUT    | `/user/profile` | Updates profile fields; omitted fields are not changed |

### PUT `/user/profile`

```json
{
  "full_name": "somebody",
  "email": "none@example.com",
  "password": "newpassword123",
  "profile_image": "https://example.com/profile.jpg"
}
```

### Restaurant Management (JWT required — owner or `super_admin`)

| Method | Path                                                    | Notes                                 |
| ------ | ------------------------------------------------------- | ------------------------------------- |
| POST   | `/restaurants`                                          | Creates a restaurant                  |
| PUT    | `/restaurants/:id`                                      | Updates restaurant details            |
| DELETE | `/restaurants/:id`                                      | Deletes a restaurant                  |
| POST   | `/restaurants/:id/categories`                           | Creates a category                    |
| PUT    | `/restaurants/:id/categories/:categoryId`               | Updates a category                    |
| DELETE | `/restaurants/:id/categories/:categoryId`               | Deletes a category                    |
| POST   | `/restaurants/:id/categories/:categoryId/foods`         | Creates a food item                   |
| PUT    | `/restaurants/:id/categories/:categoryId/foods/:foodId` | Updates a food item                   |
| DELETE | `/restaurants/:id/categories/:categoryId/foods/:foodId` | Deletes a food item                   |
| GET    | `/restaurants/:id/subscription`                         | Returns the restaurant's subscription |
| POST   | `/restaurants/:id/subscription/upgrade`                 | Upgrades the restaurant subscription  |
<!-- | GET    | `/restaurants/:id/qrcodes`                              | Lists restaurant QR codes             | -->
<!-- | DELETE | `/restaurants/:id/qrcodes/:qrId`                        | Deletes a QR code                     | -->

### POST `/restaurants`

### PUT `/restaurants/:id`

```json
{
  "name_en": "Updated Restaurant",
  "name_am": "",
  "custom_sub_link": "updated-restaurant",
  "logo": "https://example.com/logo.png",
  "banner": "https://example.com/banner.png",
  "slogan": "Updated slogan",
  "images": ["https://example.com/image1.jpg"],
  "longer_description": "Updated restaurant description.",
  "location": "Bole, Addis Ababa",
  "phone": "+251900000000",
  "open_hours": "08:00 - 23:00",
  "available_locations": ["Bole", "Kazanchis"],
  "food_specifications": "Vegetarian and vegan options available"
}
```

### POST /restaurants/:id/categories

### PUT /restaurants/:id/categories/:categoryId

```json
{
  "name": "Desert"
}
```

### POST /restaurants/:id/categories/:categoryId/foods

### PUT /restaurants/:id/categories/:categoryId/foods/:foodId

```json
{
  "name": "Special Burger",
  "price": 450,
  "rating": 5,
  "tag": "Popular",
  "description": "Our signature burger.",
  "ingredients": ["Beef", "Cheese", "Lettuce"],
  "pic": "https://example.com/burger.jpg",
  "prep_time_minutes": 15,
  "calories": 650,
  "best_pairings": ["French Fries", "Coke"],
  "spicy_or_not": false
}
```

### POST /restaurants/:id/subscription/upgrade

```json
{
  "plan": "premium",
  "duration_days": 30
}
```

### Admin (`super_admin` only)

| Method | Path                                  | Notes                                     |
| ------ | ------------------------------------- | ----------------------------------------- |
| PUT    | `/admin/profile`                      | Updates the authenticated admin's profile |
| GET    | `/admin/users`                        | Lists all users                           |
| POST   | `/admin/users`                        | Creates a user                            |
| PUT    | `/admin/users/:id`                    | Updates any user's details                |
| PUT    | `/admin/users/:id/role`               | Changes a user's role                     |
| DELETE | `/admin/users/:id`                    | Deletes a user                            |
| GET    | `/admin/restaurants`                  | Lists all restaurants                     |
| DELETE | `/admin/restaurants/:id`              | Deletes any restaurant                    |
| GET    | `/admin/subscriptions`                | Lists all subscriptions                   |
| PUT    | `/admin/restaurants/:id/subscription` | Updates a restaurant's subscription       |
| GET    | `/admin/categories`                   | Lists all categories                      |
| DELETE | `/admin/categories/:categoryId`       | Deletes any category                      |
| GET    | `/admin/foods`                        | Lists all food items                      |
| DELETE | `/admin/foods/:foodId`                | Deletes any food item                     |
| GET    | `/admin/comments`                     | Lists all comments                        |
| DELETE | `/admin/comments/:commentId`          | Deletes a comment                         |
<!-- | GET    | `/admin/qrcodes`                      | Lists all QR codes                        | -->

### PUT /admin/profile

```json
{
  "full_name": "Super Admin",
  "email": "admin@example.com",
  "password": "newpassword123",
  "profile_image": "https://example.com/profile.jpg"
}
```

### POST /admin/users

### PUT /admin/users/:id

```json
{
  "full_name": "some one",
  "email": "none@example.com",
  "password": "password123",
  "profile_image": "https://example.com/profile.jpg",
  "role": "restaurant_owner"
}
```

### PUT /admin/users/:id/role

```json
{
  "role": "restaurant_owner"
}
```

### PUT `/admin/restaurants/:id/subscription`

```json
{
  "plan": "premium",
  "duration_days": 30
}
```


## Notable design decisions

1. **Payments**: `POST /restaurants/:id/subscription/upgrade` flips a
   restaurant onto the premium plan — it does **not** process payment. Call it
   from your payment provider's webhook (Chapa, Telebirr, Stripe, etc.) once
   payment is confirmed.
2. **Image limits**: enforced server-side in `UpdateRestaurant` based on
   whether the restaurant's subscription is active premium (3 vs 6 images).
   Image _upload_ (to S3/Cloudinary/etc.) isn't included — the API expects
   already-hosted image URLs; add an upload handler if you want the backend
   to handle file storage too.
<!-- 3. **QR codes**: `POST /restaurants/:id/qrcodes` generates a PNG pointing at
   `FRONTEND_URL/menu/:custom_sub_link[?table=:table_id]`. and saves it under
   `./static/qrcodes/`. Point `FRONTEND_URL` at your actual customer-facing
   menu page. -->
3. **First super_admin**: the register endpoint blocks self-registering as
   `super_admin` on purpose. Create the first admin directly in the database,
   or add a one-off seed script.
<!-- 4. **Multilingual**: `NameEn`/`NameAm` are separate columns rather than a
   generic i18n table — simplest fit for a two-language (Eng/Amh) requirement
   like yours. Extend to a translations table if you add more languages. -->

<!-- ## Project layout

```
config/       env/config loading
database/     DB connection + auto-migration
models/       GORM models (User, Restaurant, Category, Food, Comment, Subscription, QRCode)
middleware/   JWT auth + role guards
handlers/     request handlers, grouped by resource
routes/       route wiring
utils/        JWT + password hashing helpers
``` -->
