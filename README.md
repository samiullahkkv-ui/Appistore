# Appistore

A mobile-first app discovery marketplace with free developer submissions and an admin approval workflow.

## Live site
https://appistore.vercel.app

## Features in the current frontend
- Responsive Appistore marketplace design
- Supabase email/password developer signup and login
- Free app submission form: name, category, description, icon, exactly four screenshots, and Google Drive / MediaFire HTTPS APK link
- Developer studio showing the user's submissions and review status
- Admin review queue with app previews, APK link, approve/reject and rejection reason
- Admin pin/unpin controls for approved apps; pinned apps appear in the Featured section
- Public listing displays approved apps only

## Supabase setup

Project URL: https://dwskygvkrgugkovlbzjj.supabase.co

The publishable key is configured in `index.html`. It is safe to expose a Supabase publishable key in browser code; never add a service-role key to this repository.

1. Run the core SQL in `supabase/appistore_schema.sql` in the Supabase SQL Editor once the project database is available. The core tables, role trigger, and RLS policies have been submitted as the `appistore_marketplace_core` migration.
2. Enable Supabase Storage and create a **public** bucket named `appistore-assets`, with a 5 MB per-image limit and PNG, JPG/JPEG, and WebP allowed. Then run the Storage bucket/policy section at the bottom of `supabase/appistore_schema.sql`.
3. Create your own account from the live site's Developer Login.
4. In Supabase SQL Editor, promote your own account to admin by replacing the email placeholder below with the email used for your account:

```sql
insert into public.user_roles (user_id, role)
select id, 'admin'
from auth.users
where email = 'YOUR-ADMIN-EMAIL'
on conflict (user_id) do update set role = 'admin';
```

5. Sign out and sign in again on Appistore. The Admin dashboard button will then appear.

## Security and review
- New accounts automatically receive the developer role.
- Developers can submit apps and see their own submissions.
- Public visitors can only read approved apps.
- Only an account with the admin role can approve, reject, or pin/unpin apps.
- APKs are linked from Google Drive or MediaFire; Appistore does not host APK binaries.
- Admins should manually inspect app behavior, permissions, developer identity, and download link before approval. An external APK link is not proof that a file is safe.

## Run locally
Open `index.html` in a modern browser. The Supabase project must be active and the Storage bucket configured for full upload functionality.
