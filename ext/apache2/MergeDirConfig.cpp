/*
 *  Phusion Passenger - https://www.phusionpassenger.com/
 *  Copyright (c) 2010-2013 Phusion
 *
 *  "Phusion Passenger" is a trademark of Hongli Lai & Ninh Bui.
 *
 *  See LICENSE file for license information.
 */

/*
 * MergeDirConfig.cpp is automatically generated from MergeDirConfig.cpp.erb,
 * using definitions from lib/phusion_passenger/apache2/config_options.rb.
 * Edits to MergeDirConfig.cpp will be lost.
 *
 * To update MergeDirConfig.cpp:
 *   rake apache2
 *
 * To force regeneration of MergeDirConfig.cpp:
 *   rm -f ext/apache2/MergeDirConfig.cpp
 *   rake ext/apache2/MergeDirConfig.cpp
 */




	
		config->ruby =
			(add->ruby == NULL) ?
			base->ruby :
			add->ruby;
	

	
		config->minInstances =
			(add->minInstances == UNSET_INT_VALUE) ?
			base->minInstances :
			add->minInstances;
	

	
		config->user =
			(add->user == NULL) ?
			base->user :
			add->user;
	

	
		config->group =
			(add->group == NULL) ?
			base->group :
			add->group;
	

	
		config->maxRequests =
			(add->maxRequests == UNSET_INT_VALUE) ?
			base->maxRequests :
			add->maxRequests;
	

	
		config->startTimeout =
			(add->startTimeout == UNSET_INT_VALUE) ?
			base->startTimeout :
			add->startTimeout;
	

	
		config->highPerformance =
			(add->highPerformance == DirConfig::UNSET) ?
			base->highPerformance :
			add->highPerformance;
	

	
		config->enabled =
			(add->enabled == DirConfig::UNSET) ?
			base->enabled :
			add->enabled;
	