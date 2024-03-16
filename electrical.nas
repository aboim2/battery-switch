##########################################################
####### Single Starter/Generator electrical system #######
####################    Syd Adams    #####################
###### Based on Curtis Olson's nasal electrical code #####
##########################################################
##########################################################
########    Modified by Carlos Aboim  for DC-3     #######
##########################################################

var last_time = 0.0;
var OutPuts = props.globals.getNode("/systems/electrical/outputs",1);
var Volts = props.globals.getNode("/systems/electrical/volts",1);
var Amps = props.globals.getNode("/systems/electrical/amps",1);
var PWR = props.globals.getNode("/systems/electrical/serviceable",1).getBoolValue();
var BATT = props.globals.getNode("/controls/electrical/battery-switch",1);
var ALT_L = props.globals.getNode("/controls/electric/engine[0]/generator",1);
var ALT_R = props.globals.getNode("/controls/electric/engine[1]/generator",1);
var DIMMER = props.globals.getNode("/controls/lighting/instruments-norm",1);
var GPU = props.globals.getNode("/controls/electrical/external-power",1);
var NORM = 0.0357;
var Battery={};
var Alternator={};
var load = 0.0;
var external_power={};
var switchPosition= 0;

############################################################################
############################### Ground Power Unit ##########################
############################################################################
#var External_power = External-power.new(volts, amps, amp_hours);

external_power = {
	new : func {
        m = { parents : [external_power] };
        m.ideal_volts = arg[0];
        m.ideal_amps = arg[1];
        m.amp_hours = arg[2];
     },

};

setlistener("controls/electrical/external-power", func(state) {
  external_power.available = state.getValue() == 1;
});


############################################################################
#####################   Definition of Battery   ############################
############################################################################
#var battery = Battery.new(volts, amps, amp_hours, charge_percent, charge_amps);

Battery = {
    new : func {
        m = { parents : [Battery] };
        m.ideal_volts = arg[0];
        m.ideal_amps = arg[1];
        m.amp_hours = arg[2];
        m.charge_percent = arg[3];
        m.charge_amps = arg[4];
        return m;
    },

    apply_load : func {
        var amphrs_used = arg[0] * arg[1] / 3600.0;
        var percent_used = amphrs_used / me.amp_hours;
        me.charge_percent -= percent_used;
        if ( me.charge_percent < 0.0 ) {
            me.charge_percent = 0.0;
        } elsif ( me.charge_percent > 1.0 ) {
            me.charge_percent = 1.0;
        }
        return me.amp_hours * me.charge_percent;
    },

    get_output_volts : func {
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        return me.ideal_volts * factor;
    },

    get_output_amps : func {
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        return me.ideal_amps * factor;
    }
};

############################################################################
##################### Definition of Alternators ###########################
############################################################################
# var alternator = Alternator.new("rpm-source",rpm_threshold,volts,amps);

Alternator = {
    new : func {
        m = { parents : [Alternator] };
        m.rpm_source =  props.globals.getNode(arg[0],1);
        m.rpm_threshold = arg[1];
        m.ideal_volts = arg[2];
        m.ideal_amps = arg[3];
        return m;
    },

    apply_load : func( amps, dt) {
        var factor = me.rpm_source.getValue() / me.rpm_threshold;
        if ( factor > 1.0 ){
            factor = 1.0;
        }
        var available_amps = me.ideal_amps * factor;
        return available_amps - amps;
    },

    get_output_volts : func {
        var factor = me.rpm_source.getValue() / me.rpm_threshold;
        if ( factor > 1.0 ) {
            factor = 1.0;
            }
        return me.ideal_volts * factor;
    },

    get_output_amps : func {
        var factor = me.rpm_source.getValue() / me.rpm_threshold;
        if ( factor > 1.0 ) {
            factor = 1.0;
        }
        return me.ideal_amps * factor;
    }
};



############################################################################
#############        Definitions of the power sources       ################
############################################################################

var gpu = external_power.new(28.0, 90.0, 120.0);                                                # Definition of the GPU
var battery = Battery.new(28.0, 90.0, 120.0, 1.0, 90.0); 					# Definition of Battery
var alternator_L = Alternator.new("/engines/engine[0]/rpm", 950.0, 28.0, 120.0);		# Definition of Left Alternator
var alternator_R = Alternator.new("/engines/engine[1]/rpm", 950.0, 28.0, 120.0);		# Definition of Right Alternator


############################################################################
############# Définition des propriétés à l'initialisation ################
############################################################################

setlistener("/sim/signals/fdm-initialized", func {
    foreach(var a; props.globals.getNode("/systems/electrical/outputs").getChildren()){
       a.setValue(0);
    }
    foreach(var a; props.globals.getNode("/controls/circuit-breakers").getChildren()){
       a.setBoolValue(1);
    }
    foreach(var a; props.globals.getNode("/controls/lighting").getChildren()){
       a.setValue(0);
    }
    props.globals.getNode("/controls/lighting/instrument-lights",1).setBoolValue(1);
    props.globals.getNode("/controls/anti-ice/prop-heat",1).setBoolValue(0);
    props.globals.getNode("/controls/anti-ice/pitot-heat",1).setBoolValue(0);
    props.globals.getNode("/controls/cabin/fan",1).setBoolValue(0);
    props.globals.getNode("/controls/cabin/heat",1).setBoolValue(0);
    props.globals.getNode("/controls/electrical/external-power",1).setBoolValue(1);
    props.globals.getNode("/controls/electrical/battery-switch",1).setBoolValue(1);
    props.globals.getNode("/sim/failure-manager/instrumentation/comm/serviceable",1).setBoolValue(1);
    props.globals.getNode("/instrumentation/kt76a/mode",1).setValue("0");
      #### ENGINE[0] ####
    props.globals.getNode("/controls/electric/engine[0]/generator",1).setBoolValue(1);
    props.globals.getNode("/engines/engine[0]/amp-v",1).setDoubleValue(0);
    props.globals.getNode("/controls/engines/engine[0]/master-alt",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine[0]/master-bat",1).setBoolValue(0);
      #### ENGINE[1] ####
    props.globals.getNode("/controls/electric/engine[1]/generator",1).setBoolValue(1);
    props.globals.getNode("/engines/engine[1]/amp-v",1).setDoubleValue(0);
    props.globals.getNode("/controls/engines/engine[1]/master-alt",1).setBoolValue(0);
    props.globals.getNode("/controls/engines/engine[1]/master-bat",1).setBoolValue(0);

    settimer(update_electrical,1);
    
});

# Set the switch to the OFF, GPU or Battery position
setlistener("/controls/electrical/battery-switch", func {

  if (BATT.getValue() == 2) {
    # Ignition is turned on, check for specific positions
    if (external_power.available) {
      # Use GPU if available when ignition is turned on
      switchPosition = 2;
    } else {
      # Use battery by default if ignition is turned on and no GPU
      switchPosition = 1;
    }
  } else {
    # Key is turned off (0)
    switchPosition = 0;
  }

  # Set the battery switch position based on the logic above
  setprop("controls/electrical/battery-switch", switchPosition);
});

print("Electrical System ... OK");

#############################################################################
#################### Simulation of the eletric virtual bus ##################
#############################################################################
var bus_volts = 0.0;

var update_virtual_bus = func(dt) {
    var AltVolts_L = alternator_L.get_output_volts();
    var AltAmps_L = alternator_L.get_output_amps();
    var AltVolts_R = alternator_R.get_output_volts();
    var AltAmps_R = alternator_R.get_output_amps();
    var BatVolts = battery.get_output_volts();
    var BatAmps = battery.get_output_amps();
    var gpuVolts = gpu.get_output_volts();
    var gpuAmps = gpu.get_output_amps();
    var power_source = nil;
    load = 0.0;
    load += electrical_bus(bus_volts);							# Getting Eletric Bus Amperage
											
    load += avionics_bus(bus_volts);							# Getting Avionics Amperage


    #####################################################################
    ################# Definitions of the engine tension  ################
    #####################################################################

    if(PWR){										# If the electric system isn't damaged
      if (ALT_L.getBoolValue() and (AltAmps_L > BatAmps)				# If the switch Alt Left or Alt Right are turned ON and if the power of
      or ALT_R.getBoolValue() and (AltAmps_R > BatAmps)){                               # one alternator power is higher or equals to the battery value		
          if(AltVolts_L > AltVolts_R){							
            bus_volts = AltVolts_L;							# The left alternator provide the Bus power
          }else{									
            bus_volts = AltVolts_R;							# The right alternator provide the Bus power
          }										
          power_source = "alternator";							# The alternators are the source power
          battery.apply_load(-battery.charge_amps, dt);					# and recharge the battery
      }											
      elsif (ALT_L.getBoolValue() and (AltAmps_L < BatAmps)				# If the switch Alt Left or Alt Right are turned ON and if the power of
      or ALT_R.getBoolValue() and (AltAmps_R < BatAmps)){				# one alternator power is less to the battery value
        if (BATT.getBoolValue()){							# If the switch Batt is ON 
          bus_volts = BatVolts;								# The battery is providing power to the Bus
          power_source = "battery";							# Battery is the power source
          battery.apply_load(load, dt);							# and discharge the Battery
        }										
        else {										# Or
          bus_volts = 0.0;								# The Bus tension is 0V
        }										
      }										
      elsif (BATT.getBoolValue()){							# If the switch Batt is ON
          bus_volts = BatVolts;								# The battery is providing power to the Bus
          power_source = "battery";							# Battery is the power source
          battery.apply_load(load, dt);							# and discharge the Battery
      }
      elsif (GPU.getBoolValue()){                                                       # If power isn't from Alternators or Battery it should come from GPU
         bus_volts = gpuVolts;
         power_source = "gpu";
         gpu.apply_load(load, dt);
      }											
      else {										# Or
        bus_volts = 0.0;								# The Bus tension is 0V
      }											
    } else {										# Or the electric system has issues or is damaged
        bus_volts = 0.0;								# The Bus tension is 0V
    }

    props.globals.getNode("/engines/engine[0]/amp-v",1).setValue(bus_volts);		# The engine 1 tension is equals to the Bus
    props.globals.getNode("/engines/engine[1]/amp-v",1).setValue(bus_volts);		# The engine 2 tension is equals to the Bus

    #####################################################################
    ################### Definition the the Bus Amperage #################
    #####################################################################

    var bus_amps = 0.0;

    if (bus_volts > 1.0){								# If the Bus tension is higher than 1V
        if (power_source == "battery"){							# Battery is the power source
            bus_amps = BatAmps-load;							# The intensity of the Bus is the intensity of the Battery less the intensity of the total of Buses
        } else {									# Or
            bus_amps = battery.charge_amps;						# The Bus intensity is the same intensity provided by the alternators (limité par les caractéristiques de la batterie)
        }
    }

    #####################################################################
    ######################     Applying values     ######################
    #####################################################################

    Amps.setValue(bus_amps);
    Volts.setValue(bus_volts);
    return load;
}

############################################################################
####################    Bus eletric charge measurement   ###################
############################################################################

var electrical_bus = func(bus_volts){
    var load = 0.0;
    var starter_voltsL = 0.0;
    var starter_voltsR = 0.0;

    if(props.globals.getNode("/controls/lighting/landing-lights").getBoolValue()){
        OutPuts.getNode("landing-lights",1).setValue(bus_volts);
        load += 0.0004;
    } else {
        OutPuts.getNode("landing-lights",1).setValue(0.0);
    }
    if(props.globals.getNode("/controls/lighting/landing-lights[1]").getBoolValue()){
        OutPuts.getNode("landing-lights[1]",1).setValue(bus_volts);
        load += 0.0004;
    } else {
        OutPuts.getNode("landing-lights[1]",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/running-lights").getBoolValue()){
        OutPuts.getNode("running-lights",1).setValue(bus_volts);
        load += 0.000002;
    } else {
        OutPuts.getNode("running-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/passing-lights").getBoolValue()){
        OutPuts.getNode("passing-lights",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("passing-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/recognition-lights").getBoolValue()){
        OutPuts.getNode("recognition-lights",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("recognition-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/recognition-lights[1]").getBoolValue()){
        OutPuts.getNode("recognition-lights[1]",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("recognition-lights[1]",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/recognition-lights[2]").getBoolValue()){
        OutPuts.getNode("recognition-lights[2]",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("recognition-lights[2]",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/formation-lights").getBoolValue()){
        OutPuts.getNode("formation-lights",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("formation-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/tail-lights").getBoolValue()){
        OutPuts.getNode("tail-lights",1).setValue(bus_volts);
        load += 0.000002;
    } else {
        OutPuts.getNode("tail-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/lighting/cabin-lights").getBoolValue()){
        OutPuts.getNode("cabin-lights",1).setValue(bus_volts);
        load += 0.00002;
    } else {
        OutPuts.getNode("cabin-lights",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/anti-ice/engine/carb-heat").getBoolValue()){
        OutPuts.getNode("carb-heat",1).setValue(bus_volts);
        load += 0.00002;
    } else {
        OutPuts.getNode("carb-heat",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/fuel/tank/boost-pump").getBoolValue()){
        OutPuts.getNode("boost-pump",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("boost-pump",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/fuel/tank[1]/boost-pump").getBoolValue()){
        OutPuts.getNode("boost-pump[1]",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("boost-pump[1]",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/engines/engine/fuel-pump").getBoolValue()){
        OutPuts.getNode("fuel-pump",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("fuel-pump",1).setValue(0.0);
    }

    if(props.globals.getNode("/controls/engines/engine[1]/fuel-pump").getBoolValue()){
        OutPuts.getNode("fuel-pump[1]",1).setValue(bus_volts);
        load += 0.000006;
    } else {
        OutPuts.getNode("fuel-pump[1]",1).setValue(0.0);
    }


    if (props.globals.getNode("/controls/engines/engine[0]/starter").getBoolValue()){
        starter_voltsL = bus_volts;
        load += 0.01;
    }

    if (props.globals.getNode("/controls/engines/engine[1]/starter").getBoolValue()){
        starter_voltsR = bus_volts;
        load += 0.01;
    }
    OutPuts.getNode("starter",1).setValue(starter_voltsL);
    OutPuts.getNode("starter[1]",1).setValue(starter_voltsR);

    return load;
}

############################################################################
#############    Avionics charge measurement   (Instruments)    ############
############################################################################

var avionics_bus = func(bus_volts) {
    #load = 0.0;

    if (props.globals.getNode("/controls/lighting/instrument-lights").getBoolValue() and props.globals.getNode("/controls/circuit-breakers/instrument-lights").getBoolValue()){
        var instr_norm = props.globals.getNode("/controls/lighting/instruments-norm").getValue();
        var v = instr_norm * bus_volts;
        OutPuts.getNode("instrument-lights",1).setValue(v);
        load += 0.000025;
    } else {
        OutPuts.getNode("instrument-lights",1).setValue(0.0);
    }

    if (props.globals.getNode("/instrumentation/comm/serviceable").getBoolValue() and props.globals.getNode("/sim/failure-manager/instrumentation/comm/serviceable").getBoolValue()){
        OutPuts.getNode("comm",1).setValue(bus_volts);
        load += 0.00015;
    } else {
        OutPuts.getNode("comm",1).setValue(0.0);
    }
#
#    if (props.globals.getNode("/instrumentation/kt76a/mode").getValue() > 0 and props.globals.getNode("/controls/switches/transponder").getBoolValue()){
#        OutPuts.getNode("transponder",1).setValue(bus_volts);
#        load += 0.00015;
#    } else {
#        OutPuts.getNode("transponder",1).setValue(0.0);
#    }

    if (props.globals.getNode("/instrumentation/nav/serviceable").getBoolValue() ){
        OutPuts.getNode("nav",1).setValue(bus_volts);
        load += 0.00015;
    } else {
        OutPuts.getNode("nav",1).setValue(0.0);
    }
   
   if (props.globals.getNode("/instrumentation/nav[1]/serviceable").getBoolValue() ){
        OutPuts.getNode("nav[1]",1).setValue(bus_volts);
        load += 0.000015;
    } else {
        OutPuts.getNode("nav[1]",1).setValue(0.0);
    }   
   
   if (props.globals.getNode("/instrumentation/adf/serviceable").getBoolValue() ){
        OutPuts.getNode("adf",1).setValue(bus_volts);
        load += 0.000015;
    } else {
        OutPuts.getNode("adf",1).setValue(0.0);
    }
   
   if (props.globals.getNode("/instrumentation/turn-indicator/serviceable").getBoolValue() ){
        OutPuts.getNode("turn-coordinator",1).setValue(bus_volts);
        load += 0.000015;
    } else {
        OutPuts.getNode("turn-coordinator",1).setValue(0.0);
    }

    return load;
}

var update_electrical = func {
    var time = getprop("/sim/time/elapsed-sec");
    var dt = time - last_time;
    var last_time = time;
    update_virtual_bus(dt);
    settimer(update_electrical, 0);
}
