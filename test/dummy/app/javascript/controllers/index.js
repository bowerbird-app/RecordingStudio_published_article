import { application } from "controllers/application"
import { lazyLoadControllersFrom, eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

lazyLoadControllersFrom("controllers", application)
eagerLoadControllersFrom("controllers/recording_studio_attachable", application)
