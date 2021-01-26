// Importing Module
import { Application, Router } from "https://deno.land/x/oak@v6.2.0/mod.ts";
import {
  adapterFactory,
  engineFactory,
  viewEngine,
} from "https://deno.land/x/view_engine@v1.4.5/mod.ts";
import { upload } from "https://deno.land/x/oak_upload_middleware@v2/mod.ts";

// Setting up our view Engine
const ejsEngine = engineFactory.getEjsEngine();
const oakAdapter = adapterFactory.getOakAdapter();

// Initiate our Application and Router
const app = new Application();
const router = new Router();
app.use(viewEngine(oakAdapter, ejsEngine));

// Passing Router as middleware
app.use(router.routes());
app.use(router.allowedMethods());
// Server our app
console.log("App is listening on PORT 8000");

// Setting our router to handle request
router
  .get("/", (ctx) => {
    ctx.render("index.ejs");
  })
  .post("/upload", upload("uploads"), async (context: any, next: any) => {
    const file = context.uploadedFiles;
    console.log(file);
    context.response.redirect("/");
  });

await app.listen({ port: 8000 });
