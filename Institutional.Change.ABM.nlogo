;;;;;;;; This model uses and modifies code (used in primarily in the 'cultural diffusion' sub-model here) originally developed by
;;;;;;;; Michael Maes (M.Maes@rug.nl) and Sergi Lozano (slozano@ethz.ch), Zurich, October 2008
;;;;;;;; Used with permission
;;;;;;;; Original model available here: https://www.openabm.org/book/3138/114-diffusion-culture

;;;;;;;; Model frozen on 3/1/2016 for writing

globals [agent_removed

        ;;for cultural diffusion
        number_of_regions
        regions_list
        active_agent
        closest-person
        feature_neigh
        overlap
        chosen-feature
        new-trait
        found
        loop-step
  ]

patches-own [productivity_value
             mikania_density
             mikania_cover
             ]

turtles-own [institution_cost
             value_threshold
             removal_cost
             removal_list
             three_removal_list ;; for excessive burning
             times_burned

             ;;for cultural diffusion
             feature
             region_id
             institution_type
             featval0
             ]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;SETUP;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-people
  ask patches [
    set productivity_value (random 100 / 100)
    set mikania_density one-of [ 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5]
  ]

  if mikania_gradient? [
  ask patches with [(pxcor >= -16) and (pxcor <= -8)] [set mikania_cover 0.75]
  ask patches with [(pxcor > -8) and (pxcor <= 0)] [set mikania_cover 0.5]
  ask patches with [(pxcor > 0) and (pxcor <= 8)] [set mikania_cover 0.25]
  ask patches with [(pxcor > 8) and (pxcor <= 16)] [set mikania_cover 0]

  ask patches [set pcolor scale-color green mikania_cover 1 0]
  ]

  if mikania_random? [
    ask patches [
      set mikania_cover 0 + random-float 1
      set pcolor scale-color green mikania_cover 1 0]]

  set agent_removed 0 ;; changes to 1 if the agent removes mikania

  ;;set up the number of individuals initially adopting each removal strategy
  let do_nothing n-of (num_nothing * initial-people) turtles
  ask do_nothing [set featval0 0]

  let bp n-of (num_bp * initial-people) turtles with [not member? self do_nothing]
  ask bp [set featval0 1]

  let pull n-of (num_pull * initial-people) turtles with [not member? self bp and not member? self do_nothing]
  ask pull [set featval0 2]

  let pull_bury n-of (num_pull_bury * initial-people) turtles with [not member? self pull and not member? self do_nothing and not member? self bp]
  ask pull_bury [set featval0 3]

  let burn n-of (num_burn * initial-people) turtles with [not member? self pull_bury and not member? self pull and not member? self do_nothing and not member? self bp]
  ask burn [set featval0 4]

 ;print count turtles with [featval0 = 0] ;;for testing

  ask turtles [set feature (list featval0 random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits random number_of_traits)
    recolor-agents]

  ;;for cultural diffusion
  make-regions-list
  reset-ticks
end

to setup-people
  set-default-shape turtles "person"
  create-turtles initial-people [
    setxy random-xcor random-ycor
    set institution_cost 0
    set value_threshold (random 100 / 100)
    set removal_list [0.3 0.35 0.5 0.2]
    set times_burned 0
    set three_removal_list [0.3 0.35 0.5] ;; for excessive burning fee
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;GO;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
    remove_mikania
    redistribute_mikania
  tick
  make-regions-list
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;Remove Mikania- rational choice or cultural diffusion;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to remove_mikania
     ask turtles [

       if mikania_cover != 0[ ;;cannot remove Mikania if it's not present!

         ;;;;;;;;;;;;;;;;;;;;;;;;;rational choice;;;;;;;;;;;
         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
         if rational_choice? [

    ;;selecting the institution type
    ifelse value_threshold > productivity_value  ;; agent selects removal method based on a random term (their value_threshold)
     [set removal_cost one-of removal_list ]
     [set removal_cost min removal_list] ;; this selects the removal type with the smallest cost

     if value_threshold > productivity_value [
       if observe? [

         if count turtles in-radius 1 with [removal_cost = .5] >= 5 [ set removal_cost .5]

         if count turtles in-radius 1 with [removal_cost = .35] >= 5[set removal_cost .35]

         if count turtles in-radius 1 with [removal_cost = .30] >=  5 [set removal_cost .3]

         if count turtles in-radius 1 with [removal_cost = .2] >= 5 [set removal_cost .2]
       ]
     ]

     ;;for excessive burning:
     if removal_cost = 0.2 [set times_burned times_burned + 1]

    ;;cost benefit analysis to decide whether to remove Mikania
    if removal_cost < productivity_value [ ;; only remove if value of patch is greater than cost to remove
       set institution_cost (institution_cost - removal_cost) + reputation_benefit

       if monitor_and_sanction_burning? [
         if times_burned >= 2 [
           set institution_cost institution_cost - 0.2]
             if institution_cost < -1 [
               set removal_cost one-of three_removal_list]
       ];;they paid a cost for excessive burning and switch institutions if the cost becomes too much

       set agent_removed 1

       ;;Initial amount of Mikania removed
       if removal_cost = 0.3 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]]
       if removal_cost = 0.35 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]]
       if removal_cost = 0.5 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]]
       if removal_cost = 0.2 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]]

       ;;Depending on the method used, some Mikania will be left behind and/or Mikania not removed will increase
       if removal_cost = 0.3 [ask patch-here [set mikania_cover (mikania_cover * 0.2) + mikania_cover]]
       if removal_cost = 0.35 [ask patch-here [set mikania_cover (mikania_cover * 0.1) + mikania_cover]]
       ;if removal_cost = 0.5 [ask patch-here [set mikania_cover (mikania_cover * 0) + mikania_cover]]   ;; no rate of increase for best practice removal
       if removal_cost = 0.2 [ask patch-here [set mikania_cover (mikania_cover * 0.3) + mikania_cover]]

       ;; for tracking the institution cost over time-- not evaluated in paper (for future work)
       if mikania_density >= 0.3 [
       set institution_cost institution_cost - 0.2]
       ] ;; they removed the Mikania
     ]

         ;;;;;;;;;;;;;;;;;;;;;;;;;cultural diffusion;;;;;;;;;;;
         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
         if cultural_change? [


    ;;;;;;;; Use and modification of code originally developed by Michael Maes (M.Maes@rug.nl) and Sergi Lozano (slozano@ethz.ch), Zurich, October 2008;;;;
    ;;;;;;;; Used with permission;;;;;;;
    ;;;;;;;; Original model available here: https://www.openabm.org/book/3138/114-diffusion-culture ;;;;;

    ;;;;;;;; Mutation (not Axelrod, Maes and Lozano addition);;;;
    if random-float (1.0) < mutation_rate [ask one-of turtles [set feature replace-item random (number_of_Features) feature random (number_of_traits)]]

    ;;Choose agent to be updated ;;
    set active_agent one-of turtles
    ;if report_CC = true [print [(word "("xcor", "ycor")")] of active_agent] ;;testing

   ;;Select interaction partner ;;
   ask active_agent
            [
             set closest-person min-one-of other turtles [distance myself]
             ;if report_CC = true [print closest-person] ;;testing
             set feature_neigh [feature] of closest-person
             ;;print feature_neigh ;;testing
           ]

            ;;Calculate cultural similarity ;;
            calc-overlap feature_neigh
            ;if report_CC = true [print feature] ;;testing
            ;if report_CC = true [print feature_neigh] ;;testing
            set overlap overlap / number_of_Features

       ;;Social influence ;;
       if (overlap < 1) and ((overlap > random-float 1) or (Random_interaction > (random 100) + 1)) [
           ;;print Random_interaction ;;testing
           point-dissimilar feature_neigh
           set new-trait item chosen-feature feature_neigh
           set feature replace-item chosen-feature feature new-trait

           recolor-agents
;           if report_CC = true [print overlap] ;;testing
;           if report_CC = true [print chosen-feature]
;           if report_CC = true [print feature]
;           if report_CC = true [print feature_neigh]
       ]

     ;;Remove Mikania after cultural change (or not);;
     if item 0 feature = 0 [set institution_type 0] ;; do nothing/does not remove
     if item 0 feature = 1 [set institution_type 1] ;; best practice
     if item 0 feature = 2 [set institution_type 2] ;; pulling
     if item 0 feature = 3 [set institution_type 3] ;; pull and bury
     if item 0 feature = 4 [set institution_type 4] ;; burn


     ;;Initial amount of Mikania removed
     if institution_type = 1 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]] ;.9
     if institution_type = 2 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]] ;.2
     if institution_type = 3 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]] ;.7
     if institution_type = 4 [ask patch-here [set mikania_cover mikania_cover - (mikania_cover * initial-mikania-removed)]] ;.3

     ;;Depending on the method used, some Mikania will be left behind and/or Mikania not removed will increase
     ;if institution_type = 1 [ask patch-here [set mikania_cover (mikania_cover * 0) + mikania_cover]] ;; no increase for best practice
     if institution_type = 2 [ask patch-here [set mikania_cover (mikania_cover * 0.2) + mikania_cover]]
     if institution_type = 3 [ask patch-here [set mikania_cover (mikania_cover * 0.1) + mikania_cover]]
     if institution_type = 4 [ask patch-here [set mikania_cover (mikania_cover * 0.3) + mikania_cover]]


     if institution_type != 0 [set agent_removed 1]
     ]
     ]
     ]
end

to redistribute_mikania

  ask turtles [

  if agent_removed = 1 [
    ;;pulling
    if (removal_cost = 0.3) or (institution_type = 2) [
      if [mikania_cover] of patch-here >= 0.5 [
        ;;if mikania cover in patch crosses the threshold, it will spill over into other patches
        ask neighbors [set mikania_cover 0.2 + mikania_cover]
      ]
    ]
    ;;pulling and burying
    if (removal_cost = 0.35) or (institution_type = 3) [
      if [mikania_cover] of patch-here >= 0.5 [
        ask neighbors4 [set mikania_cover 0.1 + mikania_cover]
      ]
    ]
    ;;best practice ;;no increase for best practice
;    if (removal_cost = 0.5) or (institution_type = 1) [
;      if [mikania_cover] >= 0.5 [
;        ask  [set mikania_present 1 set pcolor green]
;      ]
;    ]
    ;;burning
    if (removal_cost = 0.2) or (institution_type = 4) [
      if [mikania_cover] of patch-here >= 0.5 [
        ask neighbors [set mikania_cover 0.3 + mikania_cover]
        ;ask n-of 2 patches [set mikania_present 1 set pcolor green]
        ]
    ]
  ]
  ]
  ;;RECOLOR PATCHES after increase
  ask patches [set pcolor scale-color green mikania_cover 1 0]
end


;;;;;;;; Use and modification of code originally developed by Michael Maes (M.Maes@rug.nl) and Sergi Lozano (slozano@ethz.ch), Zurich, October 2008;;;;
;;;;;;;; Used with permission;;;;;;;
;;;;;;;; Original model available here: https://www.openabm.org/book/3138/114-diffusion-culture ;;;;;

to point-dissimilar [b] ;; determines the feature value to be copied by the selected agent from its partner
  set found false
  loop [
    set chosen-feature random number_of_Features
    if item chosen-feature feature != item chosen-feature b [set found true]
    if found [stop]
  ]
end

to calc-overlap [b] ;; calculates the similarity
  set loop-step 0
  set overlap 0
  loop [
    ;;print loop-step
    if item loop-step feature = item loop-step b [set overlap overlap + 1]
    set loop-step loop-step + 1
    if loop-step = number_of_Features [stop]
    ;;print overlap
  ]

end

to make-regions-list ;;calculate the number of norm/cultural regions
  set regions_list []
  ask turtles [
    calc-region-id
    ;print region_id ;;for testing
    set regions_list fput region_id regions_list

  ;print regions_list ;;for testing
  ]
  set regions_list remove-duplicates regions_list
  ;print regions_list ;;for testing
  set number_of_regions length regions_list
  ;print number_of_regions ;;for testing
end

to calc-region-id ;; determines an agent's region
    set region_id item 0 feature
    set loop-step 1 ;;; NEED TO set to 0 for only one feature!!!
    loop[
      set region_id region_id + (10 ^ loop-step)*(item loop-step feature)
      set loop-step loop-step + 1
      if loop-step = number_of_Features [stop]
    ]
end

to recolor-agents
     set color (20 + item 0 feature)
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
649
470
16
16
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
7
47
179
80
initial-people
initial-people
0
1000
100
100
1
NIL
HORIZONTAL

BUTTON
7
10
70
43
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
69
10
132
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
676
10
908
169
Mikania cover
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"mikania distribution" 1.0 0 -13840069 true "" "plot count patches with [mikania_cover >= 0.5]"

PLOT
677
174
985
369
Institution (removal) types
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"1" 1.0 0 -5825686 true "" "plot count turtles with [removal_cost = 0.3]"
"2" 1.0 0 -7500403 true "" "plot count turtles with [removal_cost = 0.35]"
"3" 1.0 0 -2674135 true "" "plot count turtles with [removal_cost = 0.5]"
"4" 1.0 0 -955883 true "" "plot count turtles with [removal_cost = 0.2]"

SWITCH
6
324
112
357
observe?
observe?
1
1
-1000

SWITCH
6
258
208
291
monitor_and_sanction_burning?
monitor_and_sanction_burning?
1
1
-1000

SLIDER
6
291
178
324
reputation_benefit
reputation_benefit
0
0.5
0
0.1
1
NIL
HORIZONTAL

PLOT
909
10
1203
169
Institution cost to individuals
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot mean [institution_cost] of turtles"

SWITCH
6
486
169
519
cultural_change?
cultural_change?
0
1
-1000

SLIDER
6
519
178
552
number_of_Features
number_of_Features
1
20
5
1
1
NIL
HORIZONTAL

SLIDER
6
552
178
585
number_of_traits
number_of_traits
1
20
5
1
1
NIL
HORIZONTAL

SLIDER
6
584
178
617
mutation_rate
mutation_rate
0.0
0.01
0
0.0005
1
NIL
HORIZONTAL

SLIDER
6
617
212
650
Random_interaction
Random_interaction
0
100
0
1
1
percent
HORIZONTAL

SWITCH
9
718
122
751
report_CC
report_CC
1
1
-1000

MONITOR
899
426
1019
471
Number of Regions
number_of_regions
17
1
11

PLOT
678
376
888
514
Number of Regions
Time
Number of Regions
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot number_of_regions"

PLOT
989
174
1297
369
Frequency of norm types with cultural change
Time
Turtles
0.0
200.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [item 0 feature = 0]"
"pen-1" 1.0 0 -7500403 true "" "plot count turtles with [item 0 feature = 1]"
"pen-2" 1.0 0 -2674135 true "" "plot count turtles with [item 0 feature = 2]"
"pen-3" 1.0 0 -955883 true "" "plot count turtles with [item 0 feature = 3]"
"pen-4" 1.0 0 -6459832 true "" "plot count turtles with [item 0 feature = 4]"

SWITCH
6
225
150
258
rational_choice?
rational_choice?
1
1
-1000

SLIDER
244
515
416
548
num_bp
num_bp
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
244
482
416
515
num_nothing
num_nothing
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
244
547
416
580
num_pull
num_pull
0
1
0.3
0.05
1
NIL
HORIZONTAL

SLIDER
244
578
416
611
num_pull_bury
num_pull_bury
0
1
0
0.05
1
NIL
HORIZONTAL

SLIDER
244
611
416
644
num_burn
num_burn
0
1
0.15
0.05
1
NIL
HORIZONTAL

SWITCH
7
79
179
112
mikania_gradient?
mikania_gradient?
0
1
-1000

SWITCH
7
112
179
145
mikania_random?
mikania_random?
1
1
-1000

TEXTBOX
422
484
572
547
These sliders must be set up to equal 1 (100 percent).
12
0.0
1

SLIDER
7
145
179
178
initial-mikania-removed
initial-mikania-removed
0
1
0.3
0.05
1
NIL
HORIZONTAL

TEXTBOX
14
208
164
226
For Rational Choice
11
0.0
1

TEXTBOX
11
468
161
486
For Cultural Diffusion
11
0.0
1

TEXTBOX
19
701
169
719
For testing
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This model is intended to explore how different institutions, or rules and norms, change over time in a social ecological system facing rapid change. We explore two perspectives of institutional change, rational choice and cultural diffusion, and how these in turn influence a social-ecological outcome. In particular, this model is informed by data from locally governed community forests in Chitwan, Nepal and seeks to understand how shared management norms and strategies influence the spread of a rapidly growing invasive plant, Mikania micrantha. The primary purpose of this model is to explore which theoretical perspective of institutional change is most plausible in Chitwan and draw insights about institutional change that are relevant to any social-ecological system facing global environmental changes. Thus, although the model is informed by data specific to Chitwan, we make an effort to keep the model as general and simple as possible such that it can be altered in the future to explore different aspects of the Chitwan system or other social-ecological systems entirely.

See the ODD protocol for more information.

## HOW TO USE IT

Select one of the processes of institutional change- cultural diffusion or rational choice- by turning one of these buttons to "on."

Change the settings for each type of change under the slider/button cluster for your selected type.

## CREDITS AND REFERENCES

This model uses and modifies code (used in primarily in the 'cultural diffusion' sub-model here) originally developed by Michael Maes (M.Maes@rug.nl) and Sergi Lozano (slozano@ethz.ch), Zurich, October 2008.

The code is used with permission and the original model is available here: https://www.openabm.org/book/3138/114-diffusion-culture
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Model run 1 6.30.2015" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="600"/>
    <metric>count patches with [mikania_present = 1]</metric>
    <metric>mean [institution_cost] of turtles</metric>
    <metric>count turtles with [removal_cost = 0.3]</metric>
    <metric>count turtles with [removal_cost = 0.35]</metric>
    <metric>count turtles with [removal_cost = 0.5]</metric>
    <metric>count turtles with [removal_cost = 0.2]</metric>
    <enumeratedValueSet variable="excessive_burning_fee?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="initial-people" first="100" step="100" last="1000"/>
    <enumeratedValueSet variable="observe?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="initial_mikania" first="10" step="10" last="100"/>
    <steppedValueSet variable="reputation_benefit" first="0" step="0.1" last="0.5"/>
  </experiment>
  <experiment name="Rational Choice" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count patches with [mikania_cover &gt;= 1]</metric>
    <metric>mean [institution_cost] of turtles</metric>
    <metric>count turtles with [removal_cost = 0.3]</metric>
    <metric>count turtles with [removal_cost = 0.35]</metric>
    <metric>count turtles with [removal_cost = 0.5]</metric>
    <metric>count turtles with [removal_cost = 0.2]</metric>
    <enumeratedValueSet variable="monitor_and_sanction_burning?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
      <value value="500"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial_mikania">
      <value value="10"/>
      <value value="30"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="observe?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 1_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 2_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 3_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 4_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 5_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 6_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 7_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 8_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 9_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 10_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 11_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 12_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 13_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 14_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 15_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Cultural Change_Exp 16_initial success" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>number_of_regions</metric>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>count turtles with [item 0 feature = 0]</metric>
    <metric>count turtles with [item 0 feature = 1]</metric>
    <metric>count turtles with [item 0 feature = 2]</metric>
    <metric>count turtles with [item 0 feature = 3]</metric>
    <metric>count turtles with [item 0 feature = 4]</metric>
    <enumeratedValueSet variable="num_bp">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_nothing">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_pull_bury">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num_burn">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_Features">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_traits">
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Rational Choice simple" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>count patches with [mikania_cover &gt;= 0.5]</metric>
    <metric>mean [institution_cost] of turtles</metric>
    <metric>count turtles with [removal_cost = 0.3]</metric>
    <metric>count turtles with [removal_cost = 0.35]</metric>
    <metric>count turtles with [removal_cost = 0.5]</metric>
    <metric>count turtles with [removal_cost = 0.2]</metric>
    <enumeratedValueSet variable="monitor_and_sanction_burning?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cultural_change?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="observe?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rational_choice?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
