 declare report_timing {
     {-help                       Flag           }
     {-hierarchical               Flag           }
     {-net                        Flag           }
     {-stop_at_genomes            Flag           }
     {-rise                       Flag           }
     {-fall                       Flag           }
     {-from                       List      {junk}     }
     {-rise_from                  List      {junk}  -from     }
     {-fall_from                  List      {junk}  -from     }
     {-to                         List      {junk}     }
     {-rise_to                    List      {junk}  -to     }
     {-fall_to                    List      {junk}  -to     }
     {-through                    List      {dup}}
     {-rise_through               List      {dup}    -through }
     {-fall_through               List      {dup}    -through }
     {-max_paths                  Int {($par>=1)}}
     {-nworst                     Int {($par>=1)}}
     {-mode                       String         }
     {-format                     List           }
     {-group                      String         }
     {-combined                   Flag           }
 } {!(param(-rise) && param(-fall))}
      
 # to be able to represent internal assertions
 declare set_required_time {
     {-clock                      List           }
     {-clock_fall                 Flag           }
     {-level_sensitive            Flag           }
     {-rise                       Flag           }
     {-fall                       Flag           }
     {-min                        Flag           }
     {-max                        Flag           }
     {-add_delay                  Flag           }
     {delay_value                 Float       {1}}
     {port_pin_list               List           }
     {-network_latency_included   Flag           }
     {-source_latency_included    Flag           }
     
 } {param(delay_value) && param(port_pin_list) && \
	!((param(-clock_fall) || param(-level_sensitive)) && !param(-clock))}

# some collection commands

declare foreach_in_collection {
    {var                String    }
    {coll_list          List      }
    {commands           String    }
} {param(var) && param(coll_list) && param(commands)}

declare remove_from_collection {
    {coll_list          List      }
    {remo_list          List      }
} {param(coll_list) && param(remo_list)}

declare sizeof_collection {
    {coll_list          List      }
} {param(coll_list)}

declare index_collection {
    {coll_list          List      }
    {index              Int       {($par>=0)}}
} {param(coll_list) && param(index)}

declare filter {
    {-regexp            Flag      }
    {coll_list          List      }
    {expression         String    }
} {param(coll_list) && param(expression)}

declare add_to_collection {
    {-unique            Flag      }
    {coll_list          List      }
    {obj_list           List      }
} {param(coll_list) && param(obj_list)}

declare append_to_collection {
    {var                String    }
    {obj_list           List      }
} {param(var) && param(obj_list)}

declare copy_collection {
    {coll_list          List      }
} {param(coll_list)}

declare compare_collections {
    {-order_dependent   Flag      }
    {coll_list1         List      }
    {coll_list2         List      }
} {param(coll_list1) && param(coll_list2)}

declare sort_collection {
    {-descending        Flag      }
    {-criteria          List      }
    {coll_list          List      }
} {param(coll_list)}

declare sizeof {
    {coll_list          List      }
} {param(coll_list)}

declare get_attribute {
    {-quiet             Flag      }
    {-class             String    }
    {object             List      }
    {attribute          String    }
} {param(object) && param(attribute)}

declare set_attribute {
    {-quiet             Flag      }
    {-class             String    }
    {object             String    }
    {attribute          String    }
    {value              String    }
} {param(object) && param(attribute) && param(value)}

# alias of set_attribute, but matching planAhead arg order: name,value,objects...
declare set_property {
    {-quiet             Flag      }
    {attribute          String    }
    {value              String    }
    {object             String    }
} {param(attribute) && param(value) && param(object)}

declare get_property {
    {-quiet             Flag      }
    {attribute          String    }
    {object             String    }
} {param(attribute) && param(object)}

declare remove_input_delay {
    {-clock              String   }
    {-clock_fall         Flag     }
    {-level_sensitive    Flag     }
    {-rise               Flag     }
    {-fall               Flag     }
    {-max                Flag     }
    {-min                Flag     }
    {pin_list            List     }
} {param(pin_list)}

declare remove_input_transition {
    {pin_list            List     }
} {param(pin_list)}

declare remove_driving_cell {
    {-rise               Flag     }
    {-fall               Flag     }
    {-min                Flag     }
    {-max                Flag     }
    {-clock              String   }
    {-clock_fall         Flag     }
    {pin_list            List     }
} {param(pin_list)}

declare remove_output_delay {
    {-clock              String   }
    {-clock_fall         Flag     }
    {-level_sensitive    Flag     }
    {-rise               Flag     }
    {-fall               Flag     }
    {-max                Flag     }
    {-min                Flag     }
    {pin_list            List     }
} {param(pin_list)}

declare remove_load {
    {pin_list            List     }
} {param(pin_list)}

declare all_connected {
    {-leaf               Flag     }
    {object              String   }
} {param(object)}

declare all_fanin {
    {-to                 List                  }
    {-startpoints_only   Flag                  }
    {-exclude_bboxes     Flag                  }
    {-break_on_bboxes    Flag                  }
    {-only_cells         Flag                  }
    {-flat               Flag                  }
    {-levels             Int   {1 && $par>=0}  }
    {-port_only          Flag                  }
    {-clock              String                }
	{toList              List                  }
} {(param(-to) && !param(-clock) && !param(toList)) ||
   (!param(-to) && param(-clock) && !param(toList)) ||
	(!param(-to) && !param(-clock) && param(toList))}

declare all_fanout {
    {-clock_tree         Flag                  }
    {-from               List                  }
    {-endpoints_only     Flag                  }
    {-exclude_bboxes     Flag                  }
    {-break_on_bboxes    Flag                  }
    {-only_cells         Flag                  }
    {-flat               Flag                  }
    {-levels             Int   {1 && $par>=0}  }
} {(param(-clock_tree) && !param(-from)) ||
   (!param(-clock_tree) && param(-from))}

declare get_timing_paths {
    {-from               List    {junk}             }
    {-rise_from          List    {junk}    -from    }
    {-fall_from          List    {junk}    -from    }
    {-through            List    {dup}              }
    {-rise_through       List    {dup}     -through }
    {-fall_through       List    {dup}     -through }
    {-to                 List    {junk}             }
    {-rise_to            List    {junk}    -to      }
    {-fall_to            List    {junk}    -to      }
    {-group              String                     }
    {-max_paths          Int     {1 && $par>=1}     }
}

declare get_references {
    {-hierarchical       Flag                       }
    {-quiet              Flag                       }
    {-regexp             Flag                       }
    {-nocase             Flag                       }
    {-exact              Flag                       }
    {-filter             String                     }
    {patterns            List                       }
} {param(patterns)}

declare all_designs {
}

declare set_route_layer {
    {-layer              Int {($par>=1)}            }
    {port_pin_list            List                       }
} {param(port_pin_list) && param(-layer)}

declare create_sblock {
  {-name               String     }
  {cell_list           List       }
 }

declare get_sblock {
  { name               String     }
 }

# XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
