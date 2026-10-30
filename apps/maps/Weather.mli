(* Weather: a place's forecast, asked of Open-Meteo.

     GET /v1/forecast?latitude=47.39&longitude=0.69&current=...&daily=...
         &timezone=auto
     { "current": { "time": "2026-10-30T20:30", "temperature_2m": 10.5,
                    "weather_code": 0, "wind_speed_10m": 12.7 },
       "hourly":  { "time": [...], "temperature_2m": [...] },
       "daily":   { "time": ["2026-10-30", ...], "weather_code": [1, ...],
                    "temperature_2m_max": [...], ... } }

   An answer as columns, one array a quantity, not one object an hour:
   a table, as it is computed. timezone=auto: the service works out the
   place's time zone, so a day is the place's day and not ours or UTC's,
   which a forecast for the other side of the world gets wrong otherwise.

   What it says of the sky is a number from the World Meteorological
   Organization's table of "present weather" (code table 4677), made for
   observers sending telegrams in a few digits: 0 clear, 45 fog, 61 slight
   rain, 95 thunderstorm. A hundred codes, of which a model gives some
   thirty; here they are eight kinds of picture.

   cs-history:
   Forecasting by computing is older than the computer. Vilhelm Bjerknes
   said in 1904 that the weather is a problem in mechanics and physics: a
   few equations and the present state. Lewis Fry Richardson did it, by
   hand, on the Western Front where he drove an ambulance: six weeks of
   sums for six hours of weather over two points of Germany, published in
   "Weather Prediction by Numerical Process" (1922), and wrong by a factor
   of a hundred, for a reason understood only later (his starting data was
   unbalanced). He imagined a hall of 64,000 people computing to keep up
   with the real weather. In 1950 Jule Charney, Ragnar Fjørtoft and John
   von Neumann ran the first forecast on ENIAC, a simplified atmosphere:
   24 hours took about 24 hours. Edward Lorenz, in 1963, rounding a number
   on his LGP-30, found why it can never be perfect: chaos. A forecast
   today is an ensemble of runs from slightly different starts, on the
   largest machines of ECMWF and the national services, and those are what
   Open-Meteo hands on: all we do here is read a table.

   modern:
   GraphCast (DeepMind, 2023) and its kind, trained on forty years of past
   weather, now compete with the equations for a tiny part of the cost.

   Reference: Peter Lynch, "The Emergence of Numerical Weather Prediction:
   Richardson's Dream" (Cambridge, 2006); https://open-meteo.com/en/docs;
   its data is CC BY 4.0, hence the credit under the forecast. *)

type kind = Clear | Partly | Overcast | Fog | Drizzle | Rain | Snow | Storm

type day = { date : string; code : int; high : float; low : float; rain : float }

type t = {
  time : string; (* "2026-10-30T20:30", the place's *)
  temperature : float;
  code : int;
  wind : float; (* km/h *)
  hours : (string * float) list; (* the next hours' temperatures *)
  days : day list;
}

val url : string -> float -> float -> string

(* Failure if it is not such an answer *)
val of_json : string -> t

(* the WMO's code: its picture and its words *)
val kind : int -> kind
val words : int -> string

(* "2026-10-31" -> "Sat 31" *)
val day_name : string -> string

(* a temperature in whole degrees, "10°", never "-0°" *)
val degrees : float -> string

(* the forecast as lines of text (mini-maps weather), the place's name first *)
val lines : string -> t -> string list
