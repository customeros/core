defmodule Web.LeadsController do
    use Web, :controller
  
    def index(conn, _params) do
      conn
      |> assign_prop(:companies, [
        %{name: "Acme Corp", count: 10, stage: "Target", domain: "acme.com", industry: "Manufacturing"},
        %{name: "Hooli", count: 60, stage: "Target", domain: "hooli.com", industry: "Technology"},
        %{name: "Daily Planet", count: 55, stage: "Target", domain: "dailyplanet.com", industry: "Media"},
        %{name: "Dunder Mifflin", count: 155, stage: "Target", domain: "dundermifflin.com", industry: "Paper"},
        %{name: "Gekko & Co", count: 205, stage: "Target", domain: "gekko.com", industry: "Finance"},
        %{name: "Planet Express", count: 255, stage: "Target", domain: "planetexpress.com", industry: "Delivery"},
        %{name: "Initech Solutions", count: 305, stage: "Target", domain: "initechsolutions.com", industry: "Software"},
        %{name: "Oscorp Industries", count: 355, stage: "Target", domain: "oscorpindustries.com", industry: "Biotechnology"},
        %{name: "Duff Brewery", count: 405, stage: "Target", domain: "duffbrewery.com", industry: "Beverage"},
        %{name: "Duffi Brew", count: 405, stage: "Target", domain: "duffibrew.com", industry: "Beverage"},
        %{name: "Gringotts Inc", count: 455, stage: "Target", domain: "gringottsinc.com", industry: "Banking"},
        %{name: "Sterling Inc", count: 505, stage: "Target", domain: "sterlinginc.com", industry: "Advertising"},
        %{name: "Cogswell Inc", count: 555, stage: "Target", domain: "cogswellinc.com", industry: "Manufacturing"},
        %{name: "Globex Corporation", count: 20, stage: "Education", domain: "globex.com", industry: "Technology"},
        %{name: "Stark Industries", count: 15, stage: "Education", domain: "starkindustries.com", industry: "Defense"},
        %{name: "Pied Piper", count: 65, stage: "Education", domain: "piedpiper.com", industry: "Technology"},
        %{name: "Tyrell Corporation", count: 115, stage: "Education", domain: "tyrell.com", industry: "Biotechnology"},
        %{name: "Prestige Worldwide", count: 165, stage: "Education", domain: "prestigeworldwide.com", industry: "Entertainment"},
        %{name: "Oceanic Airlines", count: 215, stage: "Education", domain: "oceanicairlines.com", industry: "Aviation"},
        %{name: "Acme Widgets", count: 265, stage: "Education", domain: "acmewidgets.com", industry: "Manufacturing"},
        %{name: "Umbrella Inc", count: 315, stage: "Education", domain: "umbrellainc.com", industry: "Pharmaceuticals"},
        %{name: "Cyberdyne Corp", count: 415, stage: "Education", domain: "cyberdynecorp.com", industry: "Technology"},
        %{name: "Soylent Corp", count: 30, stage: "Solution", domain: "soylent.com", industry: "Food"},
        %{name: "Wayne Enterprises", count: 25, stage: "Solution", domain: "wayneenterprises.com", industry: "Conglomerate"},
        %{name: "Vandelay Industries", count: 75, stage: "Solution", domain: "vandelay.com", industry: "Import/Export"},
        %{name: "Rich Industries", count: 275, stage: "Solution", domain: "richindustries.com", industry: "Conglomerate"},
        %{name: "Wonka Chocolates", count: 425, stage: "Solution", domain: "wonkachocolates.com", industry: "Confectionery"},
        %{name: "Initech", count: 40, stage: "Evaluation", domain: "initech.com", industry: "Software"},
        %{name: "Oscorp", count: 35, stage: "Evaluation", domain: "oscorp.com", industry: "Biotechnology"},
        %{name: "Duff Beer", count: 85, stage: "Evaluation", domain: "duffbeer.com", industry: "Beverage"},
        %{name: "Umbrella Corporation", count: 50, stage: "Ready to buy", domain: "umbrella.com", industry: "Pharmaceuticals"},
        %{name: "LexCorp", count: 45, stage: "Ready to buy", domain: "lexcorp.com", industry: "Conglomerate"},
        %{name: "Monsters Inc", count: 145, stage: "Ready to buy", domain: "monstersinc.com", industry: "Energy"},
        %{name: "Weyland-Yutani", count: 195, stage: "Ready to buy", domain: "weylandyutani.com", industry: "Space Exploration"},
        %{name: "Soylent Green", count: 295, stage: "Ready to buy", domain: "soylentgreen.com", industry: "Food"},
        %{name: "Wayne Tech", count: 345, stage: "Ready to buy", domain: "waynetech.com", industry: "Technology"},
        %{name: "Vandelay Corp", count: 395, stage: "Ready to buy", domain: "vandelaycorp.com", industry: "Import/Export"},
        %{name: "Bluth Industries", count: 495, stage: "Ready to buy", domain: "bluthindustries.com", industry: "Real Estate"},
        %{name: "Spacely Inc", count: 545, stage: "Ready to buy", domain: "spacelyinc.com", industry: "Manufacturing"}
      ])
      |> render_inertia("Leads")
    end
  end
  