    terraform {
      backend "http" {
        address        = "http://localhost:8081/state/codeforge_db"
        lock_address   = "http://localhost:8081/state/codeforge_db"
        unlock_address = "http://localhost:8081/state/codeforge_db"
        lock_method    = "LOCK"
        unlock_method  = "UNLOCK"
   
        # Basic auth — set TF_HTTP_USERNAME and TF_HTTP_PASSWORD in the environment,
       # or swap these for a bearer token via TF_HTTP_HEADERS.
    #    username = var.blueprints_user
    #    password = var.blueprints_password
     }
   }