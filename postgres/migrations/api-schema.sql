-- =============================================================
-- Telli API Database Schema
-- Combined migrations for telli_api_db
-- Generated from packages/api-database/migrations/
-- =============================================================

-- 0000_amused_pandemic.sql
CREATE TYPE "public"."api_key_state" AS ENUM('active', 'inactive', 'deleted');
CREATE TABLE IF NOT EXISTS "admin" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"email" text NOT NULL,
	"password_hash" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "admin_email_unique" UNIQUE("email")
);
CREATE TABLE IF NOT EXISTS "api_key" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"key_id" text NOT NULL,
	"secret_hash" text NOT NULL,
	"project_id" text NOT NULL,
	"state" "api_key_state" DEFAULT 'active' NOT NULL,
	"limit_in_cent" integer DEFAULT 0 NOT NULL,
	"previousBudgets" json DEFAULT '[]'::json NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expiresAt" timestamp
);
CREATE TABLE IF NOT EXISTS "completion_usage_tracking" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"completion_tokens" integer NOT NULL,
	"prompt_tokens" integer NOT NULL,
	"total_tokens" integer NOT NULL,
	"model_id" uuid NOT NULL,
	"api_key_id" uuid NOT NULL,
	"project_id" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "llm_model_api_key_mapping" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"llm_model_id" uuid NOT NULL,
	"api_key_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "llm_model" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"provider" text NOT NULL,
	"name" text NOT NULL,
	"display_name" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"settings" json NOT NULL,
	"price_metada" json NOT NULL,
	"organization_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "organization" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE IF NOT EXISTS "project" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"limit_in_cent" integer DEFAULT 0 NOT NULL,
	"previousBudgets" json DEFAULT '[]'::json NOT NULL,
	"organization_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "api_key" ADD CONSTRAINT "api_key_project_id_project_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."project"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "completion_usage_tracking" ADD CONSTRAINT "completion_usage_tracking_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "completion_usage_tracking" ADD CONSTRAINT "completion_usage_tracking_api_key_id_api_key_id_fk" FOREIGN KEY ("api_key_id") REFERENCES "public"."api_key"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "completion_usage_tracking" ADD CONSTRAINT "completion_usage_tracking_project_id_project_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."project"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "llm_model_api_key_mapping" ADD CONSTRAINT "llm_model_api_key_mapping_llm_model_id_llm_model_id_fk" FOREIGN KEY ("llm_model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "llm_model_api_key_mapping" ADD CONSTRAINT "llm_model_api_key_mapping_api_key_id_api_key_id_fk" FOREIGN KEY ("api_key_id") REFERENCES "public"."api_key"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "llm_model" ADD CONSTRAINT "llm_model_organization_id_organization_id_fk" FOREIGN KEY ("organization_id") REFERENCES "public"."organization"("id") ON DELETE no action ON UPDATE no action;

-- 0001_burly_arclight.sql
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "supported_image_formats" json DEFAULT '[]'::json NOT NULL;

-- 0002_previous_wither.sql
CREATE TABLE IF NOT EXISTS "image_generation_usage_tracking" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"number_of_images" integer NOT NULL,
	"model_id" uuid NOT NULL,
	"api_key_id" uuid NOT NULL,
	"project_id" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
ALTER TABLE "image_generation_usage_tracking" ADD CONSTRAINT "image_generation_usage_tracking_model_id_llm_model_id_fk" FOREIGN KEY ("model_id") REFERENCES "public"."llm_model"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "image_generation_usage_tracking" ADD CONSTRAINT "image_generation_usage_tracking_api_key_id_api_key_id_fk" FOREIGN KEY ("api_key_id") REFERENCES "public"."api_key"("id") ON DELETE no action ON UPDATE no action;
ALTER TABLE "image_generation_usage_tracking" ADD CONSTRAINT "image_generation_usage_tracking_project_id_project_id_fk" FOREIGN KEY ("project_id") REFERENCES "public"."project"("id") ON DELETE no action ON UPDATE no action;

-- 0003_graceful_goblin_queen.sql
ALTER TABLE "completion_usage_tracking" ADD COLUMN IF NOT EXISTS "costs_in_cent" real DEFAULT 0 NOT NULL;
ALTER TABLE "image_generation_usage_tracking" ADD COLUMN IF NOT EXISTS "costs_in_cent" real DEFAULT 0 NOT NULL;

-- 0004_mushy_hex.sql
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "additional_parameters" json DEFAULT '{}'::json NOT NULL;
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "is_new" boolean DEFAULT false NOT NULL;
ALTER TABLE "llm_model" ADD COLUMN IF NOT EXISTS "is_deleted" boolean DEFAULT false NOT NULL;

-- 0005_skinny_the_executioner.sql
-- (additional_parameters default was already set to {} above)

-- 0006_majestic_the_phantom.sql
ALTER TABLE "completion_usage_tracking" ALTER COLUMN "costs_in_cent" SET DATA TYPE double precision;
ALTER TABLE "image_generation_usage_tracking" ALTER COLUMN "costs_in_cent" SET DATA TYPE double precision;

-- 0007_lazy_barracuda.sql
ALTER TABLE "api_key" DROP COLUMN IF EXISTS "previousBudgets";
ALTER TABLE "image_generation_usage_tracking" DROP COLUMN IF EXISTS "number_of_images";
ALTER TABLE "project" DROP COLUMN IF EXISTS "limit_in_cent";
ALTER TABLE "project" DROP COLUMN IF EXISTS "previousBudgets";

-- 0008_flaky_bedlam.sql
CREATE INDEX IF NOT EXISTS "api_key_project_id_index" ON "api_key" USING btree ("project_id");
CREATE INDEX IF NOT EXISTS "api_key_key_id_index" ON "api_key" USING btree ("key_id");
CREATE INDEX IF NOT EXISTS "completion_usage_tracking_api_key_id_index" ON "completion_usage_tracking" USING btree ("api_key_id");
CREATE INDEX IF NOT EXISTS "completion_usage_tracking_created_at_index" ON "completion_usage_tracking" USING btree ("created_at");
CREATE INDEX IF NOT EXISTS "image_generation_usage_tracking_api_key_id_index" ON "image_generation_usage_tracking" USING btree ("api_key_id");
CREATE INDEX IF NOT EXISTS "image_generation_usage_tracking_created_at_index" ON "image_generation_usage_tracking" USING btree ("created_at");
CREATE INDEX IF NOT EXISTS "llm_model_api_key_mapping_llm_model_id_index" ON "llm_model_api_key_mapping" USING btree ("llm_model_id");
CREATE INDEX IF NOT EXISTS "llm_model_api_key_mapping_api_key_id_index" ON "llm_model_api_key_mapping" USING btree ("api_key_id");
CREATE INDEX IF NOT EXISTS "llm_model_organization_id_index" ON "llm_model" USING btree ("organization_id");
CREATE INDEX IF NOT EXISTS "project_organization_id_index" ON "project" USING btree ("organization_id");

-- 0009_long_falcon.sql
ALTER TABLE "completion_usage_tracking" DROP CONSTRAINT IF EXISTS "completion_usage_tracking_project_id_project_id_fk";
ALTER TABLE "image_generation_usage_tracking" DROP CONSTRAINT IF EXISTS "image_generation_usage_tracking_project_id_project_id_fk";
ALTER TABLE "completion_usage_tracking" DROP COLUMN IF EXISTS "project_id";
ALTER TABLE "image_generation_usage_tracking" DROP COLUMN IF EXISTS "project_id";

-- 0010_reflective_starfox.sql
DROP INDEX IF EXISTS "completion_usage_tracking_api_key_id_index";
DROP INDEX IF EXISTS "completion_usage_tracking_created_at_index";
DROP INDEX IF EXISTS "image_generation_usage_tracking_api_key_id_index";
DROP INDEX IF EXISTS "image_generation_usage_tracking_created_at_index";
CREATE INDEX IF NOT EXISTS "completion_usage_tracking_api_key_id_created_at_index" ON "completion_usage_tracking" USING btree ("api_key_id","created_at");
CREATE INDEX IF NOT EXISTS "image_generation_usage_tracking_api_key_id_created_at_index" ON "image_generation_usage_tracking" USING btree ("api_key_id","created_at");
