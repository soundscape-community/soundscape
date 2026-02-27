//
//  SpatialReadContracts.swift
//  Soundscape
//
//  Copyright (c) Soundscape Community Contributers.
//

import Foundation
import SSDataContracts
import SSGeo

typealias SpatialIntersectionRegion = SSDataContracts.SpatialIntersectionRegion
typealias RouteReadMetadata = SSDataContracts.RouteReadMetadata
typealias ReferenceReadMetadata = SSDataContracts.ReferenceReadMetadata
typealias ReferenceCalloutReadData = SSDataContracts.ReferenceCalloutReadData
typealias EstimatedAddressReadData = SSDataContracts.EstimatedAddressReadData
typealias AddressCacheRecord = SSDataContracts.AddressCacheRecord

@MainActor
protocol RouteReadContract: SpatialRouteReadContract,
                            SpatialRouteParametersReadContract
where RouteParametersValue == RouteParameters,
      RouteParametersContextValue == RouteParameters.Context {}

@MainActor
protocol ReferenceReadContract: SpatialReferenceReadContract,
                                SpatialReferenceMarkerReadContract,
                                SpatialPointOfInterestReadContract
where MarkerParametersValue == MarkerParameters,
      PointOfInterestValue == POI,
      GenericLocationValue == GenericLocation {}

@MainActor
protocol TileReadContract: SpatialTileReadContract where Tile == VectorTile, NearbyLocation == POI {}

@MainActor
protocol SpatialReadContract: RouteReadContract,
                              ReferenceReadContract,
                              TileReadContract {}

@MainActor
protocol SpatialWriteContract: SpatialRouteWriteContract,
                               SpatialReferenceWriteContract
where GenericLocationValue == GenericLocation {}

@MainActor
protocol SpatialMaintenanceWriteContract: SpatialRouteMaintenanceWriteContract,
                                          SpatialAddressMaintenanceWriteContract,
                                          SpatialReferenceMaintenanceWriteContract
where MarkerParametersValue == MarkerParameters,
      PointOfInterestValue == POI {}
