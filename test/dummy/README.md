# Dummy App

This Rails app is the Published Articles host. It shows the same article list in three parent contexts: the studio workspace, the Product Docs folder, and The Atlantic.

## What it covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Workspace and Folder parents for articles, plus an optional Publication parent
- PDF and screenshot copies through Attachable
- Recording Studio default layout, FlatPack, and Tailwind source scanning
- Mounted Published Articles, Attachable, Publications, Recording Studio, and Root Switchable engines

## Quick start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run those commands from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Useful routes

- `/` - workspace, folder, and publication article indexes
- `/recording_studio_published_article/recordings/:recording_id/articles` - index for one parent
- `/recording_studio_published_article/articles/:id` - article detail
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` - dummy-only starter pages
- `/up` - Rails health check

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`.
