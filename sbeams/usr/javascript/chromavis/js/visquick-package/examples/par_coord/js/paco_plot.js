
function paco_plot(div1) {
    //var kmeans is imported in the .json file
    var data_array = kmeans;

    var listener = function(d) { console.log("Listener function returned" + d); return false; };
    var    pa_co = new vq.PaCo();

    var dataObject ={DATATYPE : "vq.models.PaCoData",
        CONTENTS : {
            PLOT : {
                container: div1,
                width : 1000,
                height: 500,
                vertical_padding : 30,
                horizontal_padding: 90
            },
            data_array: data_array,
            CONFIGURATION : {
                identifier_column : 'filename',
                label_column : 'filename',
                COORD_COLUMN_ARRAY : [
                    {id:'read_count',
                        label:'read_count',
                        scale_type : 'linear',
                        notifier: listener
                    },
                    {id:'total_coverage',
                        label:'total_coverage',
                        scale_type : 'linear',
                        notifier: listener
                    },
                    {id:'any_mapping_ratio',
                        label:'any_mapping_ratio',
                        scale_type : 'linear',
                        notifier: listener
                    },
                    {id:'query_mapping_ratio',
                        label:'query_mapping_ratio',
                        scale_type : 'linear',
                        notifier: listener
                    },
                    {id:'mate_mapping_ratio',
                        label:'mate_mapping_ratio',
                        scale_type : 'linear',
                        notifier: listener
                    },
                    {id:'avg_mapping_quality',
                        label:'any_mapping_quality',
                        scale_type : 'linear',
                        notifier: listener
                    },
                    {id:'avg_read_size',
                        label:'any_read_size',
                        scale_type : 'linear',
                        notifier: listener
                    }

                ]
            },
            OPTIONS : {

            }
        }};

    pa_co.draw(dataObject);
    document.getElementById('button_div').style.display = 'block';
    return pa_co;
}
