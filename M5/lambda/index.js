// Load the SDK for JavaScript
var AWS = require('aws-sdk'); //load aws-sdk into variable
// Set the region 
AWS.config.update({region: 'us-west-2'});
var ddb = new AWS.DynamoDB({apiVersion: '2012-08-10'}); //creating dynamoDB var using constructor 

exports.handler = (event, context, callback) => {
    // TODO implement
        var params = {
            ExpressionAttributeValues: {
                ':p': {S: event.headers["querytext"]}, //return 1 item from the table 
            },
            KeyConditionExpression: 'ProjectEnvironment = :p', //primayKey = p
            TableName: 'ddt-datasource'
        };

    ddb.query(params, function(err, data) {
        if (err) {
            console.log("Error", err);
            callback(err);
        } else {
            var responseBody = '{'; //building json response to external source 
            data.Items.forEach(function(item) { //iterating through each item in the query 
            responseBody += '"ProjectEnvironment":"' + item.ProjectEnvironment.S
            + '","asg_instance_size":"' + item.asg_instance_size.S
            + '","asg_min_size":"' + item.asg_min_size.S
            + '","asg_max_size":"' + item.asg_max_size.S
            + '","environment":"' + item.environment.S
            + '","billing_code":"' + item.billing_code.S
            + '","project_code":"' + item.project_code.S
            + '","network_lead":"' + item.network_lead.S
            + '","application_lead":"' + item.application_lead.S
            + '","rds_engine":"' + item.rds_engine.S
            + '","rds_version":"' + item.rds_version.S
            + '","rds_instance_size":"' + item.rds_instance_size.S
            + '","rds_multi_az":"' + item.rds_multi_az.S
            + '","rds_storage_size":"' + item.rds_storage_size.S
            + '","rds_db_name":"' + item.rds_db_name.S
            + '","vpc_subnet_count":"' + item.vpc_subnet_count.S
            + '","vpc_cidr_range":"' + item.vpc_cidr_range.S
            + '"}';
        });
            var response = { //final var to structure everything properly 
                "statusCode" : 200,
                "headers": {},
                "body": responseBody,
                "isBase64Encoded": false
            };
            callback(null, response); //this func sents it out of lambda to whatever called it initially 
        }
    });
};